import AppKit
import ApplicationServices
import Carbon

@MainActor
protocol HotkeyEventSource: AnyObject {
    var hasPermission: Bool { get }
    var isRunning: Bool { get }
    var isSecureInput: Bool { get }
    func start(handler: @escaping (CGEventType, CGEvent) -> Void) -> Bool
    func resume() -> Bool
    func stop()
    func requestPermission()
}

@MainActor
final class MacHotkeyEventSource: HotkeyEventSource {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((CGEventType, CGEvent) -> Void)?

    var hasPermission: Bool { CGPreflightListenEventAccess() || AXIsProcessTrusted() }
    var isSecureInput: Bool { IsSecureEventInputEnabled() }
    var isRunning: Bool {
        guard let eventTap else { return false }
        return CFMachPortIsValid(eventTap) && CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start(handler: @escaping (CGEventType, CGEvent) -> Void) -> Bool {
        stop()
        let events: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            // The tap's source is attached only to the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<MacHotkeyEventSource>.fromOpaque(userInfo).takeUnretainedValue().handler?(type, event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        self.handler = handler
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard isRunning else { stop(); return false }
        return true
    }

    func resume() -> Bool {
        guard hasPermission, let eventTap, CFMachPortIsValid(eventTap) else { return false }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return isRunning
    }

    func stop() {
        handler = nil
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
    }

    func requestPermission() {
        guard !hasPermission else { return }
        _ = CGRequestListenEventAccess()
        if !hasPermission,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
