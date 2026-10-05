import AppKit
import ApplicationServices
import Carbon
import MumlaCore

enum HotkeyMonitorStatus: Equatable {
    case stopped
    case active
    case inputMonitoringRequired
    case unavailable
}

@MainActor
final class ControlHotkeyMonitor {
    var onHoldStarted: (() -> Void)?
    var onHoldEnded: (() -> Void)?
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onCancel: (() -> Void)?
    var onStatusChanged: ((HotkeyMonitorStatus) -> Void)?
    private(set) var status: HotkeyMonitorStatus = .stopped
    private let source: any HotkeyEventSource
    private let now: () -> TimeInterval
    private var triggerKey: DictationTriggerKey = .control
    private var gesture = DictationHotkeyGesture()
    private var holdTimer: Timer?

    init(source: any HotkeyEventSource = MacHotkeyEventSource(), now: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.source = source
        self.now = now
    }

    func setTriggerKey(_ key: DictationTriggerKey) {
        guard triggerKey != key else { return }
        holdTimer?.invalidate()
        dispatch(gesture.reset())
        triggerKey = key
        start()
    }

    func start(forceRestart: Bool = false) {
        if !forceRestart, source.isRunning, source.hasPermission {
            setStatus(.active)
            return
        }
        holdTimer?.invalidate()
        dispatch(gesture.reset())
        source.stop()
        guard source.hasPermission else {
            setStatus(.inputMonitoringRequired)
            return
        }
        let started = source.start { [weak self] type, event in self?.handle(type: type, event: event) }
        setStatus(started ? .active : source.hasPermission ? .unavailable : .inputMonitoringRequired)
    }

    func stop() {
        holdTimer?.invalidate()
        dispatch(gesture.reset())
        source.stop()
        setStatus(.stopped)
    }

    func requestPermission() {
        source.requestPermission()
        start(forceRestart: true)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            holdTimer?.invalidate()
            dispatch(gesture.reset())
            if source.resume() {
                setStatus(.active)
            } else {
                source.stop()
                setStatus(source.hasPermission ? .unavailable : .inputMonitoringRequired)
            }
            return
        }
        if source.isSecureInput {
            holdTimer?.invalidate()
            dispatch(gesture.reset())
            return
        }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            holdTimer?.invalidate()
            _ = gesture.reset()
            onCancel?()
            return
        }
        guard type == .flagsChanged else {
            holdTimer?.invalidate()
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
        let now = now()
        if isTriggerEvent, down, !gesture.isPressed {
            dispatch(gesture.press(at: now, eligible: alone))
            let timer = Timer(timeInterval: 0.25, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleHoldThreshold() }
            }
            holdTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else if isTriggerEvent, !down {
            holdTimer?.invalidate()
            dispatch(gesture.release(at: now))
        } else if !alone {
            holdTimer?.invalidate()
            dispatch(gesture.interrupt())
        }
    }

    func handleHoldThreshold() {
        holdTimer?.invalidate()
        holdTimer = nil
        guard status == .active, !source.isSecureInput else {
            dispatch(gesture.reset())
            return
        }
        dispatch(gesture.tick(at: now()))
    }

    private func setStatus(_ status: HotkeyMonitorStatus) {
        guard self.status != status else { return }
        self.status = status
        onStatusChanged?(status)
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
