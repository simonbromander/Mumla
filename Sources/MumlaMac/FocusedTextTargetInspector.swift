import ApplicationServices
import AppKit
import Carbon
import Foundation

enum FocusedTextTarget {
    case editableText
    case secureText
    case nonText
    case unknown
}

enum FocusedTextTargetInspector {
    static func captureEditableTarget() -> FocusedTextTargetSnapshot? {
        guard !IsSecureEventInputEnabled(), AccessibilityPermission.isTrusted,
              let element = focusedElement(), inspect(element: element) == .editableText else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return FocusedTextTargetSnapshot(element: element, processID: pid)
    }

    static func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool {
        guard !IsSecureEventInputEnabled(), AccessibilityPermission.isTrusted,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processID,
              let current = focusedElement(), CFEqual(current, target.element) else { return false }
        return inspect(element: current) == .editableText
    }

    static func value(for target: FocusedTextTargetSnapshot) -> String? {
        guard isFocused(target) else { return nil }
        return textValue(from: target.element)
    }

    static func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? {
        guard isFocused(target) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target.element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

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

    static func focusedEditableValue() -> String? {
        guard
            AccessibilityPermission.isTrusted,
            let element = focusedElement(),
            inspect(element: element) == .editableText
        else {
            return nil
        }

        return textValue(from: element)
    }

    private static func inspect(element: AXUIElement) -> FocusedTextTarget {
        let role = stringAttribute(kAXRoleAttribute, from: element)
        let subrole = stringAttribute(kAXSubroleAttribute, from: element)

        if subrole == "AXSecureTextField" || role == "AXSecureTextField" {
            return .secureText
        }

        if isEditableTextRole(role) || role == "AXGroup" || role == "AXWebArea" {
            var enabled: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled) == .success,
               let enabled = enabled as? Bool, !enabled { return .nonText }
            var editable: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editable)
            // Browser and Electron editors can accept paste without AX setters.
            return acceptsPaste(role: role, enabled: enabled as? Bool, editable: editable as? Bool) ? .editableText : .nonText
        }

        if role == nil {
            return .unknown
        }

        return .nonText
    }

    private static func focusedElement() -> AXUIElement? {
        guard !IsSecureEventInputEnabled() else { return nil }
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
            return nil
        }

        return unsafeDowncast(focusedValue, to: AXUIElement.self)
    }

    static func acceptsPaste(role: String?, enabled: Bool?, editable: Bool?) -> Bool {
        guard enabled != false, editable != false else { return false }
        if isEditableTextRole(role) { return true }
        return editable == true && (role == "AXGroup" || role == "AXWebArea")
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

    private static func textValue(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if result == .success {
            if let text = value as? String { return text }
            if let attributedText = value as? NSAttributedString { return attributedText.string }
        }

        // Rich editors can expose text-range APIs without exposing AXValue.
        var countValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString, &countValue) == .success,
              let countValue, CFGetTypeID(countValue) == CFNumberGetTypeID(),
              let count = countValue as? Int, count >= 0, count <= 1_000_000 else { return nil }
        var range = CFRange(location: 0, length: count)
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        guard !IsSecureEventInputEnabled(), AccessibilityPermission.isTrusted,
              let current = focusedElement(), CFEqual(current, element),
              inspect(element: current) == .editableText else { return nil }
        var textValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &textValue
        ) == .success else { return nil }
        return textValue as? String
    }
}

struct FocusedTextTargetSnapshot {
    let element: AXUIElement
    let processID: pid_t
}
