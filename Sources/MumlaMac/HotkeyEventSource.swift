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
    private var eventTapID: UInt32?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((CGEventType, CGEvent) -> Void)?

    static let requiredEvents: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
    static var requiredEventMask: CGEventMask {
        requiredEvents.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
    }

    var hasPermission: Bool { CGPreflightListenEventAccess() }
    var isSecureInput: Bool { IsSecureEventInputEnabled() }
    var isRunning: Bool {
        guard let eventTap, let eventTapID, CFMachPortIsValid(eventTap), CGEvent.tapIsEnabled(tap: eventTap),
              let info = Self.eventTaps()?.first(where: { $0.eventTapID == eventTapID }) else { return false }
        return Self.isGlobalListener(info, processID: getpid())
    }

    func start(handler: @escaping (CGEventType, CGEvent) -> Void) -> Bool {
        stop()
        guard hasPermission, let previousTaps = Self.eventTaps() else { return false }
        let previousIDs = Set(previousTaps.map(\.eventTapID))
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
            eventsOfInterest: Self.requiredEventMask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
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
        // A valid port can still have keyboard events removed by macOS.
        eventTapID = Self.eventTaps()?.first(where: {
            !previousIDs.contains($0.eventTapID) && $0.tappingProcess == getpid()
                && $0.tapPoint == .cgSessionEventTap && $0.processBeingTapped == 0
                && $0.options == .listenOnly
        })?.eventTapID
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
        eventTapID = nil
    }

    static func isGlobalListener(_ info: CGEventTapInformation, processID: pid_t) -> Bool {
        info.tappingProcess == processID && info.processBeingTapped == 0
            && info.tapPoint == .cgSessionEventTap && info.options == .listenOnly && info.enabled
            && (info.eventsOfInterest & requiredEventMask) == requiredEventMask
    }

    private static func eventTaps() -> [CGEventTapInformation]? {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success else { return nil }
        guard count > 0 else { return [] }
        var taps = Array(repeating: CGEventTapInformation(), count: Int(count))
        var returnedCount: UInt32 = 0
        let result = taps.withUnsafeMutableBufferPointer {
            CGGetEventTapList(count, $0.baseAddress, &returnedCount)
        }
        guard result == .success else { return nil }
        return Array(taps.prefix(Int(min(count, returnedCount))))
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
