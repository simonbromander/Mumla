import AppKit
import CoreGraphics
import Foundation
import IOKit.hid

enum DJIMicButtonStatus: Equatable {
    case off, paused, permissionRequired, waitingForReceiver, ready, receiverUnavailable, helperRunning
}

struct DJIMicButtonEvent {
    let deviceID: UInt64
    let vendorID: Int
    let productID: Int
    let usagePage: UInt32
    let usage: UInt32
    let value: Int
    let timestamp: TimeInterval
}

/// Accept short down/up reports and reject reported pairing holds.
struct DJIMicButtonFilter {
    static let vendorID = 0x2ca3
    static let productID = 0x4011
    static let usagePage: UInt32 = 0x0c
    static let usages: Set<UInt32> = [0xe9, 0xea]
    private struct Button: Hashable { let deviceID: UInt64; let usage: UInt32 }
    private var pressed: [Button: TimeInterval] = [:]
    private var lastTap: [UInt64: TimeInterval] = [:]

    mutating func accepts(_ event: DJIMicButtonEvent) -> Bool {
        guard event.vendorID == Self.vendorID, event.productID == Self.productID,
              event.usagePage == Self.usagePage, Self.usages.contains(event.usage),
              event.timestamp.isFinite, event.value >= 0 else { return false }
        let button = Button(deviceID: event.deviceID, usage: event.usage)
        if event.value > 0 {
            if pressed[button] == nil { pressed[button] = event.timestamp }
            return false
        }
        guard let start = pressed.removeValue(forKey: button) else { return false }
        let duration = event.timestamp - start
        guard duration >= 0, duration <= 0.8 else { return false }
        if let previous = lastTap[event.deviceID], event.timestamp - previous < 0.35 { return false }
        lastTap[event.deviceID] = event.timestamp
        return true
    }

    mutating func disconnect(_ deviceID: UInt64) {
        pressed = pressed.filter { $0.key.deviceID != deviceID }
        lastTap.removeValue(forKey: deviceID)
    }
}

@MainActor
protocol DJIMicButtonEventSource: AnyObject {
    var hasPermission: Bool { get }
    var isRunning: Bool { get }
    func start(value: @escaping (DJIMicButtonEvent) -> Void,
               status: @escaping (DJIMicButtonStatus) -> Void, disconnected: @escaping (UInt64) -> Void)
    func stop()
    func requestPermission()
}

@MainActor
final class DJIMicButtonMonitor {
    static let legacyHelperBundleID = "com.simonbromander.dji-mic-mumla"
    var onStatusChanged: ((DJIMicButtonStatus) -> Void)?
    var onPress: ((UInt64) async -> Void)?
    var onDisconnect: ((UInt64) async -> Void)?
    private(set) var status: DJIMicButtonStatus = .off
    private let source: any DJIMicButtonEventSource
    private let helperIsRunning: () -> Bool
    private var enabled = false
    private var suspended = false
    private var generation = UUID()
    private var filter = DJIMicButtonFilter()

    init(source: any DJIMicButtonEventSource = MacDJIMicButtonEventSource(),
         helperIsRunning: @escaping () -> Bool = {
             !NSRunningApplication.runningApplications(withBundleIdentifier: DJIMicButtonMonitor.legacyHelperBundleID).isEmpty
         }) {
        self.source = source
        self.helperIsRunning = helperIsRunning
    }

    func setEnabled(_ enabled: Bool) { self.enabled = enabled; refresh(forceRestart: true) }
    func suspend() { suspended = true; refresh() }
    func resume() { suspended = false; refresh(forceRestart: true) }
    func stop() { enabled = false; halt(); update(.off) }

    func requestPermission() {
        guard enabled, !suspended else { return }
        source.requestPermission()
        refresh(forceRestart: true)
    }

    func refresh(forceRestart: Bool = false) {
        guard enabled else { halt(); update(.off); return }
        guard !suspended else { halt(); update(.paused); return }
        guard !helperIsRunning() else { halt(); update(.helperRunning); return }
        guard source.hasPermission else { halt(); update(.permissionRequired); return }
        if source.isRunning && status != .receiverUnavailable && !forceRestart { return }
        halt()
        let token = generation
        source.start(value: { [weak self] event in
            guard let self, self.generation == token, self.enabled, !self.suspended, self.status == .ready,
                  self.filter.accepts(event) else { return }
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                await self.onPress?(event.deviceID)
            }
        }, status: { [weak self] status in
            guard let self, self.generation == token else { return }
            self.update(status)
        }, disconnected: { [weak self] deviceID in
            guard let self, self.generation == token else { return }
            self.filter.disconnect(deviceID)
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                await self.onDisconnect?(deviceID)
            }
        })
    }

    private func halt() {
        generation = UUID()
        source.stop()
        filter = DJIMicButtonFilter()
    }
    private func update(_ status: DJIMicButtonStatus) {
        self.status = status
        onStatusChanged?(status)
    }
}

/// Open only the receiver's consumer-control interface. Its audio interface remains available to Core Audio.
@MainActor
final class MacDJIMicButtonEventSource: DJIMicButtonEventSource {
    private var manager: IOHIDManager?
    private var devices: [UInt64: IOHIDDevice] = [:]
    private var unavailable: Set<UInt64> = []
    private var valueHandler: ((DJIMicButtonEvent) -> Void)?
    private var statusHandler: ((DJIMicButtonStatus) -> Void)?
    private var disconnectedHandler: ((UInt64) -> Void)?
    var hasPermission: Bool { CGPreflightListenEventAccess() }
    var isRunning: Bool { manager != nil }

    static let matching: [String: Int] = [
        kIOHIDVendorIDKey: DJIMicButtonFilter.vendorID, kIOHIDProductIDKey: DJIMicButtonFilter.productID,
        kIOHIDDeviceUsagePageKey: Int(DJIMicButtonFilter.usagePage), kIOHIDDeviceUsageKey: 1
    ]

    func start(value: @escaping (DJIMicButtonEvent) -> Void,
               status: @escaping (DJIMicButtonStatus) -> Void, disconnected: @escaping (UInt64) -> Void) {
        stop()
        guard hasPermission else { status(.permissionRequired); return }
        valueHandler = value; statusHandler = status; disconnectedHandler = disconnected
        status(.waitingForReceiver)
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
        self.manager = manager
        IOHIDManagerSetDeviceMatching(manager, Self.matching as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<MacDJIMicButtonEventSource>.fromOpaque(context).takeUnretainedValue().attach(device, result: result)
            }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<MacDJIMicButtonEventSource>.fromOpaque(context).takeUnretainedValue().detach(device)
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        if IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) != kIOReturnSuccess {
            stop(); status(.receiverUnavailable)
        }
    }

    func stop() {
        valueHandler = nil; statusHandler = nil; disconnectedHandler = nil
        for device in devices.values { close(device) }
        devices.removeAll(); unavailable.removeAll()
        if let manager {
            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
    }

    func requestPermission() {
        guard !hasPermission else { return }
        _ = CGRequestListenEventAccess()
        if !hasPermission, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func attach(_ device: IOHIDDevice, result: IOReturn) {
        guard let id = identifier(device), devices[id] == nil else { return }
        guard result == kIOReturnSuccess,
              IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)) == kIOReturnSuccess else {
            unavailable.insert(id); publishStatus(); return
        }
        devices[id] = device
        unavailable.remove(id)
        IOHIDDeviceRegisterInputValueCallback(device, { context, result, _, value in
            guard let context, result == kIOReturnSuccess else { return }
            MainActor.assumeIsolated {
                Unmanaged<MacDJIMicButtonEventSource>.fromOpaque(context).takeUnretainedValue().receive(value)
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        publishStatus()
    }

    private func detach(_ device: IOHIDDevice) {
        guard let id = identifier(device) else { return }
        if let opened = devices.removeValue(forKey: id) { close(opened) }
        unavailable.remove(id)
        disconnectedHandler?(id)
        publishStatus()
    }

    private func receive(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        guard let id = identifier(device), devices[id] != nil else { return }
        valueHandler?(DJIMicButtonEvent(deviceID: id,
            vendorID: (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue ?? 0,
            productID: (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? 0,
            usagePage: IOHIDElementGetUsagePage(element), usage: IOHIDElementGetUsage(element),
            value: IOHIDValueGetIntegerValue(value), timestamp: Double(IOHIDValueGetTimeStamp(value)) * Self.secondsPerTick))
    }

    private func publishStatus() {
        statusHandler?(!devices.isEmpty ? .ready : unavailable.isEmpty ? .waitingForReceiver : .receiverUnavailable)
    }
    private func identifier(_ device: IOHIDDevice) -> UInt64? {
        var id: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == kIOReturnSuccess else { return nil }
        return id
    }
    private func close(_ device: IOHIDDevice) {
        IOHIDDeviceRegisterInputValueCallback(device, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    private static let secondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }()
}
