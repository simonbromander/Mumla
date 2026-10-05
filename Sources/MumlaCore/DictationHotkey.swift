import Foundation

public enum DictationTriggerKey: String, Codable, CaseIterable, Sendable {
    case control
    case rightOption
    case function

    public var displayName: String {
        switch self {
        case .control: "Ctrl"
        case .rightOption: "Right Option"
        case .function: "Fn"
        }
    }
}

public struct DictationHotkeyGesture: Sendable {
    public enum Action: Equatable, Sendable { case startHold, endHold, tap, doubleTap, cancel }
    public private(set) var isPressed = false
    private var pressedAt: TimeInterval?
    private var lastTapAt: TimeInterval?
    private var holding = false
    private var cancelled = false

    public init() {}

    public mutating func press(at time: TimeInterval, eligible: Bool) -> [Action] {
        guard !isPressed else { return [] }
        isPressed = true
        pressedAt = time
        holding = false
        cancelled = !eligible
        guard eligible else { lastTapAt = nil; return [] }
        if let lastTapAt, time - lastTapAt <= 0.35 {
            self.lastTapAt = nil
            cancelled = true
            return [.doubleTap]
        }
        lastTapAt = nil
        return []
    }

    public mutating func tick(at time: TimeInterval) -> [Action] {
        guard isPressed, !cancelled, !holding, let pressedAt, time - pressedAt >= 0.25 else { return [] }
        holding = true
        return [.startHold]
    }

    public func remainingHoldDelay(at time: TimeInterval) -> TimeInterval? {
        guard isPressed, !cancelled, !holding, let pressedAt else { return nil }
        return max(0, 0.25 - (time - pressedAt))
    }

    public mutating func release(at time: TimeInterval) -> [Action] {
        guard isPressed else { return [] }
        isPressed = false
        pressedAt = nil
        if holding { holding = false; return [.endHold] }
        guard !cancelled else { cancelled = false; return [] }
        lastTapAt = time
        return [.tap]
    }

    public mutating func interrupt() -> [Action] {
        let wasHolding = holding
        holding = false
        cancelled = true
        lastTapAt = nil
        return wasHolding ? [.cancel] : []
    }

    public mutating func reset() -> [Action] {
        let actions = interrupt()
        self = Self()
        return actions
    }
}
