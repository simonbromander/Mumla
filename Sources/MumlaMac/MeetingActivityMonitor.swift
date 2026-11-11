import AppKit
import CoreAudio
import Foundation

@MainActor
protocol MeetingActivityMonitoring: AnyObject {
    var onChange: (([DetectedMeetingApp], Bool) -> Void)? { get set }
    func start()
    func refresh()
    func stop()
}

/// HAL property observation only: deliberately no audio engine or process tap.
@MainActor
final class MeetingActivityMonitor: MeetingActivityMonitoring {
    var onChange: (([DetectedMeetingApp], Bool) -> Void)?
    private struct Listener {
        let object: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }
    private var systemListener: Listener?
    private var inputListeners: [AudioObjectID: Listener] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var running = false
    var isObserving: Bool { systemListener != nil }

    func start() {
        guard !running else { refresh(); return }
        guard #available(macOS 14.2, *) else { onChange?([], false); return }
        running = true
        systemListener = listen(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
        guard systemListener != nil else { stop(); onChange?([], false); return }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
    }

    func refresh() {
        guard running else { return }
        guard let objects = processObjects() else { onChange?([], false); return }
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> DetectedMeetingApp? in
            guard let bundleID = app.bundleIdentifier, let kind = MeetingAppKind.identify(bundleID) else { return nil }
            return DetectedMeetingApp(id: app.processIdentifier, bundleID: bundleID, kind: kind)
        }
        var matching: Set<AudioObjectID> = []
        var active: Set<Int32> = []
        var observable = true
        for object in objects {
            guard let pid = uint32(object, kAudioProcessPropertyPID) else { continue }
            let process = MeetingAudioProcessState(pid: Int32(bitPattern: pid), bundleID: bundleID(object) ?? "",
                                                   inputActive: uint32(object, kAudioProcessPropertyIsRunningInput) == 1)
            guard let app = apps.first(where: process.belongs) else { continue }
            matching.insert(object)
            if inputListeners[object] == nil {
                inputListeners[object] = listen(object, kAudioProcessPropertyIsRunningInput)
                if inputListeners[object] == nil { observable = false }
            }
            if process.inputActive { active.insert(app.id) }
        }
        for object in Array(inputListeners.keys) where !matching.contains(object) {
            if let listener = inputListeners.removeValue(forKey: object) { remove(listener) }
        }
        onChange?(apps.filter { active.contains($0.id) }, observable)
    }

    func stop() {
        running = false
        if let systemListener { remove(systemListener) }
        systemListener = nil
        for listener in inputListeners.values { remove(listener) }
        inputListeners.removeAll()
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
    }

    private func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Listener? {
        var address = address(selector)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
        guard AudioObjectAddPropertyListenerBlock(object, &address, .main, block) == noErr else { return nil }
        return Listener(object: object, address: address, block: block)
    }

    private func remove(_ listener: Listener) {
        var address = listener.address
        AudioObjectRemovePropertyListenerBlock(listener.object, &address, .main, listener.block)
    }

    private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private func processObjects() -> [AudioObjectID]? {
        var address = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return nil }
        guard size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = objects.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else { return nil }
        return Array(objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = address(selector), value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func bundleID(_ object: AudioObjectID) -> String? {
        var address = address(kAudioProcessPropertyBundleID)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
