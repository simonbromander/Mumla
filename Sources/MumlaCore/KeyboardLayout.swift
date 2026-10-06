import Foundation

public enum MumlaKeyboardLayout: String, CaseIterable, Sendable {
    case letters, numbers, symbols
    public var rows: [[String]] {
        switch self {
        case .letters:
            return [Array("qwertyuiopå").map(String.init), Array("asdfghjklöä").map(String.init), Array("zxcvbnm").map(String.init)]
        case .numbers:
            return [Array("1234567890").map(String.init), ["-", "/", ":", ";", "(", ")", "kr", "&", "@", "\""], [".", ",", "?", "!", "'"]]
        case .symbols:
            return [["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], ["_", "\\", "|", "~", "<", ">", "€", "$", "£", "•"], [".", ",", "?", "!", "'"]]
        }
    }
}

public struct MumlaKeyboardShift: Equatable, Sendable {
    public private(set) var uppercase = false
    public private(set) var locked = false
    private var lastTap: TimeInterval?
    private var manual = false
    public init() {}
    public mutating func tap(at time: TimeInterval) {
        manual = true
        if locked { uppercase = false; locked = false; lastTap = nil }
        else if let lastTap, time - lastTap >= 0, time - lastTap < 0.35 { uppercase = true; locked = true; self.lastTap = nil }
        else { uppercase.toggle(); lastTap = time }
    }
    public mutating func updateAutomatic(_ enabled: Bool) { if !locked && !manual { uppercase = enabled } }
    public mutating func didType() { if !locked { uppercase = false }; lastTap = nil; manual = false }
    public mutating func reset() { uppercase = false; locked = false; lastTap = nil; manual = false }
}
