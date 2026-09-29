import AppKit
import ApplicationServices
import Carbon
import MumlaCore

@MainActor
final class ControlHotkeyMonitor {
    var onHoldStarted: (() -> Void)?
    var onHoldEnded: (() -> Void)?
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onCancel: (() -> Void)?
    private var triggerKey: DictationTriggerKey = .control
    private var gesture = DictationHotkeyGesture()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdWorkItem: DispatchWorkItem?

    func setTriggerKey(_ key: DictationTriggerKey) {
        holdWorkItem?.cancel()
        dispatch(gesture.reset())
        triggerKey = key
    }

    func start() {
        guard eventTap == nil else { return }
        let events: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            // This event tap is installed only on the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<ControlHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                         eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            holdWorkItem?.cancel()
            dispatch(gesture.reset())
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }
        if IsSecureEventInputEnabled() {
            holdWorkItem?.cancel()
            dispatch(gesture.reset())
            return
        }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            holdWorkItem?.cancel()
            _ = gesture.reset()
            onCancel?()
            return
        }
        guard type == .flagsChanged else {
            holdWorkItem?.cancel()
            dispatch(gesture.interrupt())
            return
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isTriggerEvent: Bool
        let down: Bool
        let allowed: CGEventFlags
        switch triggerKey {
        case .control:
            isTriggerEvent = code == 59 || code == 62
            down = flags.contains(.maskControl)
            allowed = .maskControl
        case .rightOption:
            isTriggerEvent = code == 61
            down = flags.rawValue & UInt64(NX_DEVICERALTKEYMASK) != 0
            allowed = .maskAlternate
        case .function:
            isTriggerEvent = code == 63
            down = flags.contains(.maskSecondaryFn)
            allowed = .maskSecondaryFn
        }
        let modifiers: CGEventFlags = [.maskControl, .maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]
        let alone = flags.rawValue & modifiers.rawValue & ~allowed.rawValue == 0
        let now = CACurrentMediaTime()
        if isTriggerEvent, down, !gesture.isPressed {
            dispatch(gesture.press(at: now, eligible: alone))
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if IsSecureEventInputEnabled() { self.dispatch(self.gesture.reset()); return }
                self.dispatch(self.gesture.tick(at: CACurrentMediaTime()))
            }
            holdWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        } else if isTriggerEvent, !down {
            holdWorkItem?.cancel()
            dispatch(gesture.release(at: now))
        } else if !alone {
            holdWorkItem?.cancel()
            dispatch(gesture.interrupt())
        }
    }

    private func dispatch(_ actions: [DictationHotkeyGesture.Action]) {
        for action in actions {
            switch action {
            case .startHold: onHoldStarted?()
            case .endHold: onHoldEnded?()
            case .tap: onTap?()
            case .doubleTap: onDoubleTap?()
            case .cancel: onCancel?()
            }
        }
    }
}
