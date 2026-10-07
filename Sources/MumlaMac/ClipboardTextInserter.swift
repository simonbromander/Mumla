import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ClipboardTextInserter {
    private let system: any TextInsertionSystem
    private let pasteboard: NSPasteboard
    private let verificationDelays: [Duration]
    private let modifierReleaseDelays: [Duration]
    private(set) var lastOutcome = TextInsertionOutcome.notAttempted

    init(system: any TextInsertionSystem = MacTextInsertionSystem(), pasteboard: NSPasteboard = .general,
         verificationDelays: [Duration] = Array(repeating: .milliseconds(50), count: 16),
         modifierReleaseDelays: [Duration] = Array(repeating: .milliseconds(25), count: 12)) {
        self.system = system
        self.pasteboard = pasteboard
        self.verificationDelays = verificationDelays
        self.modifierReleaseDelays = modifierReleaseDelays
    }

    func insert(_ text: String, target: FocusedTextTargetSnapshot?) async -> ClipboardInsertionResult {
        lastOutcome = .notAttempted
        guard !text.isEmpty else { return manualCopy(.emptyText) }
        if let failure = preflight(target) { return failure }
        guard let target else { return manualCopy(.targetUnavailable) }

        // A private event source does not release physically held modifiers in the destination app.
        for delay in modifierReleaseDelays {
            if system.areModifiersReleased { break }
            do { try await Task.sleep(for: delay) } catch { return manualCopy(.cancelled) }
            if let failure = preflight(target) { return failure }
        }
        guard system.areModifiersReleased else { return manualCopy(.modifiersHeld) }

        let before = system.value(for: target)
        let selectedRange = system.selectedRange(for: target)
        if let failure = preflight(target) { return failure }
        guard system.areModifiersReleased else { return manualCopy(.modifiersHeld) }
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore(ifUnchanged: pasteboard.changeCount, to: pasteboard)
            return manualCopy(.clipboardUnavailable)
        }
        let pasteChangeCount = pasteboard.changeCount
        defer { snapshot.restore(ifUnchanged: pasteChangeCount, to: pasteboard) }
        if let failure = preflight(target) { return failure }
        guard system.areModifiersReleased else { return manualCopy(.modifiersHeld) }
        guard pasteboard.changeCount == pasteChangeCount else { return manualCopy(.clipboardChanged) }
        guard system.postPasteShortcut(to: target) else { return manualCopy(.postFailed) }

        // Read until the editor applies the paste; posting an event is not an acknowledgement.
        for delay in verificationDelays {
            do { try await Task.sleep(for: delay) } catch { return manualCopy(.cancelled) }
            if let failure = preflight(target) { return failure }
            if Self.verifiesInsertion(text, before: before, after: system.value(for: target), selectedRange: selectedRange) {
                lastOutcome = .confirmed
                return .inserted
            }
        }
        return manualCopy(before == nil ? .textUnavailable : .unconfirmed)
    }

    private func preflight(_ target: FocusedTextTargetSnapshot?) -> ClipboardInsertionResult? {
        guard !Task.isCancelled else { return manualCopy(.cancelled) }
        if system.isSecureInput {
            lastOutcome = .secureInput
            return .blockedSecureField
        }
        guard let target else { return manualCopy(.targetUnavailable) }
        guard system.isFocused(target) else { return manualCopy(.targetChanged) }
        guard system.canPostEvents else { return manualCopy(.permissionRequired) }
        return nil
    }

    private func manualCopy(_ outcome: TextInsertionOutcome) -> ClipboardInsertionResult {
        lastOutcome = outcome
        return .needsCopy(copied: false)
    }

    static func verifiesInsertion(_ text: String, before: String?, after: String?, selectedRange: NSRange?) -> Bool {
        guard !text.isEmpty, let before, let after else { return false }
        let original = before as NSString
        if let range = selectedRange {
            guard range.location >= 0, range.length >= 0,
                  range.location <= original.length, range.length <= original.length - range.location else { return false }
            let expected = original.replacingCharacters(in: range, with: text)
            if normalizedLineEndings(expected) == normalizedLineEndings(after) { return true }
            // Some custom editors report a stale collapsed range. Still require one exact insertion.
            guard range.length == 0 else { return false }
        }

        // Some editors expose their text but not a cursor range. Confirm a single insertion.
        let baseline = normalizedLineEndings(before)
        let insertedText = normalizedLineEndings(text)
        let updated = normalizedLineEndings(after) as NSString
        guard updated.length == (baseline as NSString).length + (insertedText as NSString).length else { return false }
        var search = NSRange(location: 0, length: updated.length)
        while search.length > 0 {
            let match = updated.range(of: insertedText, options: .literal, range: search)
            guard match.location != NSNotFound else { return false }
            if updated.replacingCharacters(in: match, with: "") == baseline { return true }
            let next = match.location + 1
            search = NSRange(location: next, length: updated.length - next)
        }
        return false
    }

    private static func normalizedLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }
}

enum TextInsertionOutcome: String {
    case notAttempted, confirmed, targetUnavailable, targetChanged, permissionRequired
    case secureInput, modifiersHeld, clipboardUnavailable, clipboardChanged, postFailed, unconfirmed, cancelled, emptyText, textUnavailable
}

@MainActor
protocol TextInsertionSystem {
    var isSecureInput: Bool { get }
    var canPostEvents: Bool { get }
    var areModifiersReleased: Bool { get }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool
    func value(for target: FocusedTextTargetSnapshot) -> String?
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange?
    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool
}

@MainActor
struct MacTextInsertionSystem: TextInsertionSystem {
    var isSecureInput: Bool { FocusedTextTargetInspector.inspect() == .secureText }
    var canPostEvents: Bool { CGPreflightPostEventAccess() }
    var areModifiersReleased: Bool {
        let modifiers: CGEventFlags = [.maskControl, .maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]
        return CGEventSource.flagsState(.hidSystemState).intersection(modifiers).isEmpty
    }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool { FocusedTextTargetInspector.isFocused(target) }
    func value(for target: FocusedTextTargetSnapshot) -> String? { FocusedTextTargetInspector.value(for: target) }
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? { FocusedTextTargetInspector.selectedRange(for: target) }

    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool {
        guard
            canPostEvents, isFocused(target), !isSecureInput, areModifiersReleased,
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
