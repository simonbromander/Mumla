import ApplicationServices
import Carbon
import Foundation

enum FocusedTextTarget {
    case editableText
    case secureText
    case nonText
    case unknown
}

enum FocusedTextTargetInspector {
    static func inspect() -> FocusedTextTarget {
        if IsSecureEventInputEnabled() {
            return .secureText
        }

        guard AccessibilityPermission.isTrusted else {
            return .unknown
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard
            result == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return .unknown
        }

        let element = unsafeDowncast(focusedValue, to: AXUIElement.self)
        return inspect(element: element)
    }

    private static func inspect(element: AXUIElement) -> FocusedTextTarget {
        let role = stringAttribute(kAXRoleAttribute, from: element)
        let subrole = stringAttribute(kAXSubroleAttribute, from: element)

        if subrole == "AXSecureTextField" || role == "AXSecureTextField" {
            return .secureText
        }

        if isEditableTextRole(role) {
            return .editableText
        }

        if role == nil {
            return .unknown
        }

        return .nonText
    }

    private static func isEditableTextRole(_ role: String?) -> Bool {
        switch role {
        case "AXTextField", "AXTextArea", "AXComboBox":
            return true
        default:
            return false
        }
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }
}
