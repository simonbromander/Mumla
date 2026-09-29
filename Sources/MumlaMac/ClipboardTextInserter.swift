import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ClipboardTextInserter {
    func insert(_ text: String, target: FocusedTextTargetSnapshot?) async -> ClipboardInsertionResult {
        if FocusedTextTargetInspector.inspect() == .secureText { return .blockedSecureField }
        guard let target, FocusedTextTargetInspector.isFocused(target) else {
            return copyFallback(text)
        }

        let before = FocusedTextTargetInspector.value(for: target)
        let selectedRange = FocusedTextTargetInspector.selectedRange(for: target)
        let snapshot = ClipboardSnapshot.capture()
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else {
            snapshot.restore(ifUnchanged: NSPasteboard.general.changeCount)
            return .needsCopy(copied: false)
        }
        let pasteChangeCount = NSPasteboard.general.changeCount
        guard postPasteShortcut() else { return .needsCopy(copied: true) }

        try? await Task.sleep(for: .milliseconds(200))
        let after = FocusedTextTargetInspector.value(for: target)
        let verified = Self.verifiesInsertion(text, before: before, after: after, selectedRange: selectedRange)
        if verified {
            snapshot.restore(ifUnchanged: pasteChangeCount)
            return .inserted
        }
        return .needsCopy(copied: NSPasteboard.general.changeCount == pasteChangeCount)
    }

    static func verifiesInsertion(_ text: String, before: String?, after: String?, selectedRange: NSRange?) -> Bool {
        guard let before, let after, let range = selectedRange else { return false }
        let original = before as NSString
        guard range.location <= original.length, range.length <= original.length - range.location else { return false }
        return original.replacingCharacters(in: range, with: text) == after
    }

    private func copyFallback(_ text: String) -> ClipboardInsertionResult {
        NSPasteboard.general.clearContents()
        return .needsCopy(copied: NSPasteboard.general.setString(text, forType: .string))
    }

    private func postPasteShortcut() -> Bool {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
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
