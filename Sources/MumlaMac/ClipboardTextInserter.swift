import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ClipboardTextInserter {
    private let system: any TextInsertionSystem
    private let pasteboard: NSPasteboard
    private let verificationDelays: [Duration]
    private let modifierReleaseDelays: [Duration]
    private let lateVerificationDelays: [Duration]
    private var pendingVerification: PendingVerification?
    private var fallbackClipboardChangeCount: Int?
    private(set) var lastOutcome = TextInsertionOutcome.notAttempted

    init(system: any TextInsertionSystem = MacTextInsertionSystem(), pasteboard: NSPasteboard = .general,
         verificationDelays: [Duration] = Array(repeating: .milliseconds(50), count: 16),
         modifierReleaseDelays: [Duration] = Array(repeating: .milliseconds(25), count: 12),
         lateVerificationDelays: [Duration] = Array(repeating: .milliseconds(100), count: 50)) {
        self.system = system
        self.pasteboard = pasteboard
        self.verificationDelays = verificationDelays
        self.modifierReleaseDelays = modifierReleaseDelays
        self.lateVerificationDelays = lateVerificationDelays
    }

    func insert(_ text: String, target: FocusedTextTargetSnapshot?) async -> ClipboardInsertionResult {
        lastOutcome = .notAttempted
        pendingVerification = nil
        fallbackClipboardChangeCount = pasteboard.changeCount
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
        let canUseClipboardFallback = pasteboard.changeCount == fallbackClipboardChangeCount
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            if snapshot.restore(ifUnchanged: pasteboard.changeCount, to: pasteboard), canUseClipboardFallback {
                fallbackClipboardChangeCount = pasteboard.changeCount
            }
            return manualCopy(.clipboardUnavailable)
        }
        let pasteChangeCount = pasteboard.changeCount
        if canUseClipboardFallback { fallbackClipboardChangeCount = pasteChangeCount }
        defer {
            if snapshot.restore(ifUnchanged: pasteChangeCount, to: pasteboard), canUseClipboardFallback {
                fallbackClipboardChangeCount = pasteboard.changeCount
            }
        }
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
        let result = manualCopy(before == nil ? .textUnavailable : .unconfirmed)
        if let before {
            pendingVerification = PendingVerification(text: text, before: before, selectedRange: selectedRange, target: target)
        }
        return result
    }

    func copyFallbackTranscript(_ text: String) -> ClipboardFallbackOutcome {
        pendingVerification = nil
        guard !text.isEmpty, lastOutcome != .cancelled, lastOutcome != .confirmed else { return .unavailable }
        // Automatic fallback must not replace something the user copied during or after insertion.
        let expectedCount = fallbackClipboardChangeCount ?? pasteboard.changeCount
        guard pasteboard.changeCount == expectedCount else { return .clipboardChanged }
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        guard pasteboard.changeCount == expectedCount else { return .clipboardChanged }
        let copyChangeCount = pasteboard.clearContents()
        guard pasteboard.changeCount == copyChangeCount else { return .clipboardChanged }
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore(ifUnchanged: pasteboard.changeCount, to: pasteboard)
            return .unavailable
        }
        fallbackClipboardChangeCount = pasteboard.changeCount
        return .copied
    }

    func confirmPendingInsertion(_ text: String) async -> Bool {
        guard let pending = pendingVerification, pending.text == text else { return false }
        defer { if pendingVerification?.id == pending.id { pendingVerification = nil } }
        // The clipboard has already been restored. Only observe; never send a second paste.
        for delay in lateVerificationDelays {
            do { try await Task.sleep(for: delay) } catch { return false }
            guard pendingVerification?.id == pending.id, !Task.isCancelled,
                  !system.isSecureInput, system.isFocused(pending.target) else { return false }
            let after = system.value(for: pending.target)
            guard !system.isSecureInput, system.isFocused(pending.target) else { return false }
            if Self.verifiesInsertion(text, before: pending.before, after: after, selectedRange: pending.selectedRange) {
                lastOutcome = .confirmed
                return true
            }
        }
        return false
    }

    private struct PendingVerification {
        let id = UUID()
        let text: String
        let before: String
        let selectedRange: NSRange?
        let target: FocusedTextTargetSnapshot
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
        }
        let baseline = normalizedEditorText(before)
        let insertedText = normalizedEditorText(text)
        let updated = normalizedEditorText(after)
        // Chromium rich-text editors report an empty field as "\n" and drop it once text is inserted.
        if !baseline.isEmpty, baseline.allSatisfy({ $0 == "\n" }) {
            let newlines = CharacterSet(charactersIn: "\n")
            let inserted = insertedText.trimmingCharacters(in: newlines)
            if !inserted.isEmpty, updated.trimmingCharacters(in: newlines) == inserted { return true }
        }
        if let range = selectedRange {
            // Apply the UTF-16 range before normalizing, since CRLF changes offsets.
            let expected = normalizedEditorText(original.replacingCharacters(in: range, with: text))
            if updated == expected || updated == expected + "\n" { return true }
            // Some custom editors report a stale collapsed range. Still require one exact insertion.
            guard range.length == 0 else { return false }
        }

        // Some editors expose their text but not a cursor range. Confirm a single insertion.
        if verifiesSingleInsertion(insertedText, before: baseline, after: updated) { return true }
        // A rich editor can add one paragraph terminator to its Accessibility value.
        guard updated.hasSuffix("\n") else { return false }
        return verifiesSingleInsertion(insertedText, before: baseline, after: String(updated.dropLast()))
    }

    private static func verifiesSingleInsertion(_ insertedText: String, before baseline: String, after: String) -> Bool {
        let updated = after as NSString
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

    private static func normalizedEditorText(_ text: String) -> String {
        // Compare rendered equivalents only; never change the text sent to the editor.
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
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

enum ClipboardFallbackOutcome: Equatable {
    case copied, clipboardChanged, unavailable
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
