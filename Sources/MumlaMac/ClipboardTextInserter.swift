import AppKit
import ApplicationServices
import Foundation

final class ClipboardTextInserter {
    func insert(_ text: String) -> ClipboardInsertionResult {
        if !AccessibilityPermission.isTrusted {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return .copied
        }

        switch FocusedTextTargetInspector.inspect() {
        case .secureText:
            return .blockedSecureField
        case .nonText:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return .copied
        case .editableText, .unknown:
            break
        }

        let snapshot = ClipboardSnapshot.capture()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        postPasteShortcut()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            snapshot.restore()
        }
        return .inserted
    }

    private func postPasteShortcut() {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

enum ClipboardInsertionResult {
    case inserted
    case copied
    case blockedSecureField
}

private struct ClipboardSnapshot {
    var items: [[ClipboardItemData]]

    static func capture() -> ClipboardSnapshot {
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type -> ClipboardItemData? in
                guard let data = item.data(forType: type) else { return nil }
                return ClipboardItemData(type: type, data: data)
            }
        } ?? []
        return ClipboardSnapshot(items: items)
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restoredItems = items.map { values in
            let item = NSPasteboardItem()
            for value in values {
                item.setData(value.data, forType: value.type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}

private struct ClipboardItemData {
    var type: NSPasteboard.PasteboardType
    var data: Data
}
