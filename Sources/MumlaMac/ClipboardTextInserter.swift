import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ClipboardTextInserter {
    private let system: any TextInsertionSystem
    private let pasteboard: NSPasteboard
    private let verificationDelays: [Duration]

    init(system: any TextInsertionSystem = MacTextInsertionSystem(), pasteboard: NSPasteboard = .general,
         verificationDelays: [Duration] = Array(repeating: .milliseconds(50), count: 16)) {
        self.system = system
        self.pasteboard = pasteboard
        self.verificationDelays = verificationDelays
    }

    func insert(_ text: String, target: FocusedTextTargetSnapshot?) async -> ClipboardInsertionResult {
        if system.isSecureInput { return .blockedSecureField }
        guard let target, system.isFocused(target) else { return .needsCopy(copied: false) }
        guard system.canPostEvents else { return .needsCopy(copied: false) }

        let before = system.value(for: target)
        let selectedRange = system.selectedRange(for: target)
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore(ifUnchanged: pasteboard.changeCount, to: pasteboard)
            return .needsCopy(copied: false)
        }
        let pasteChangeCount = pasteboard.changeCount
        defer { snapshot.restore(ifUnchanged: pasteChangeCount, to: pasteboard) }
        guard !system.isSecureInput, system.isFocused(target), system.postPasteShortcut(to: target) else {
            return .needsCopy(copied: false)
        }

        // Read until the editor applies the paste; posting an event is not an acknowledgement.
        for delay in verificationDelays {
            do { try await Task.sleep(for: delay) } catch { break }
            guard !system.isSecureInput, system.isFocused(target) else { break }
            if Self.verifiesInsertion(text, before: before, after: system.value(for: target), selectedRange: selectedRange) {
                return .inserted
            }
        }
        return .needsCopy(copied: false)
    }

    static func verifiesInsertion(_ text: String, before: String?, after: String?, selectedRange: NSRange?) -> Bool {
        guard !text.isEmpty, let before, let after else { return false }
        let original = before as NSString
        if let range = selectedRange {
            guard range.location >= 0, range.length >= 0,
                  range.location <= original.length, range.length <= original.length - range.location else { return false }
            return original.replacingCharacters(in: range, with: text) == after
        }

        // Some editors expose their text but not a cursor range. Confirm a single insertion.
        let updated = after as NSString
        guard updated.length == original.length + (text as NSString).length else { return false }
        var search = NSRange(location: 0, length: updated.length)
        while search.length > 0 {
            let match = updated.range(of: text, options: .literal, range: search)
            guard match.location != NSNotFound else { return false }
            if updated.replacingCharacters(in: match, with: "") == before { return true }
            let next = match.location + 1
            search = NSRange(location: next, length: updated.length - next)
        }
        return false
    }
}

@MainActor
protocol TextInsertionSystem {
    var isSecureInput: Bool { get }
    var canPostEvents: Bool { get }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool
    func value(for target: FocusedTextTargetSnapshot) -> String?
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange?
    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool
}

@MainActor
struct MacTextInsertionSystem: TextInsertionSystem {
    var isSecureInput: Bool { FocusedTextTargetInspector.inspect() == .secureText }
    var canPostEvents: Bool { CGPreflightPostEventAccess() }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool { FocusedTextTargetInspector.isFocused(target) }
    func value(for target: FocusedTextTargetSnapshot) -> String? { FocusedTextTargetInspector.value(for: target) }
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? { FocusedTextTargetInspector.selectedRange(for: target) }

    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool {
        guard
            canPostEvents, isFocused(target), !isSecureInput,
            let source = CGEventSource(stateID: .privateState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(target.processID)
        keyUp.postToPid(target.processID)
        return true
    }
}

enum ClipboardInsertionResult {
    case inserted
    case needsCopy(copied: Bool)
    case blockedSecureField
}

struct ClipboardSnapshot {
    var items: [[ClipboardItemData]]

    static func capture(from pasteboard: NSPasteboard = .general) -> ClipboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type -> ClipboardItemData? in
                guard let data = item.data(forType: type) else { return nil }
                return ClipboardItemData(type: type, data: data)
            }
        } ?? []
        return ClipboardSnapshot(items: items)
    }

    @discardableResult
    func restore(ifUnchanged changeCount: Int, to pasteboard: NSPasteboard = .general) -> Bool {
        // Never replace something the user copied while paste was being delivered.
        guard pasteboard.changeCount == changeCount else { return false }
        pasteboard.clearContents()
        guard !items.isEmpty else { return true }
        let restoredItems = items.map { values in
            let item = NSPasteboardItem()
            for value in values { item.setData(value.data, forType: value.type) }
            return item
        }
        return pasteboard.writeObjects(restoredItems)
    }
}

struct ClipboardItemData {
    var type: NSPasteboard.PasteboardType
    var data: Data
}
