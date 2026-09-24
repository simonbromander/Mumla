import AppKit
import ApplicationServices
import Foundation

final class ControlHotkeyMonitor {
    var onHoldStarted: (@MainActor () -> Void)?
    var onHoldEnded: (@MainActor () -> Void)?
    var onTap: (@MainActor () -> Void)?
    var onDoubleTap: (@MainActor () -> Void)?
    var onCancel: (@MainActor () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var controlDown = false
    private var holdStarted = false
    private var cancelled = false
    private var lastTapTime: CFTimeInterval?
    private var holdWorkItem: DispatchWorkItem?

    func start() {
        let events: [CGEventType] = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel
        ]
        let mask = events.reduce(CGEventMask(0)) { partial, event in
            partial | (1 << CGEventMask(event.rawValue))
        }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<ControlHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            if controlDown {
                cancelCurrentGesture()
            }
        default:
            break
        }
    }

    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let isControlNowDown = flags.contains(.maskControl)
        let onlyControl = isControlNowDown && flags.intersection([.maskCommand, .maskAlternate, .maskShift]).isEmpty

        if isControlNowDown && !controlDown {
            beginControlDown(eligibleForHold: onlyControl)
        } else if !isControlNowDown && controlDown {
            endControlDown()
        } else if controlDown && !onlyControl {
            cancelCurrentGesture()
        }
    }

    private func beginControlDown(eligibleForHold: Bool) {
        controlDown = true
        holdStarted = false
        cancelled = !eligibleForHold

        guard eligibleForHold else { return }

        let now = CACurrentMediaTime()
        if let lastTapTime, now - lastTapTime <= 0.35 {
            self.lastTapTime = nil
            cancelled = true
            callOnMain(onDoubleTap)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.controlDown, !self.cancelled else { return }
            self.holdStarted = true
            self.callOnMain(self.onHoldStarted)
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func endControlDown() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        controlDown = false

        if holdStarted {
            holdStarted = false
            callOnMain(onHoldEnded)
            return
        }

        guard !cancelled else {
            cancelled = false
            return
        }

        lastTapTime = CACurrentMediaTime()
        callOnMain(onTap)
    }

    private func cancelCurrentGesture() {
        let wasHolding = holdStarted
        holdWorkItem?.cancel()
        holdWorkItem = nil
        cancelled = true
        holdStarted = false
        if wasHolding {
            callOnMain(onCancel)
        }
    }

    private func callOnMain(_ callback: (@MainActor () -> Void)?) {
        guard let callback else { return }
        Task { @MainActor in
            callback()
        }
    }
}

private extension CGEventFlags {
    func intersection(_ flags: CGEventFlags) -> CGEventFlags {
        CGEventFlags(rawValue: rawValue & flags.rawValue)
    }
}
