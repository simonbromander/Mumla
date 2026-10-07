import Foundation

public enum KeyboardSessionDuration: Int, CaseIterable, Sendable {
    case fifteenMinutes = 15
    case oneHour = 60
    case twoHours = 120

    public static let defaultValue = Self.oneHour
    public static let preferenceKey = "mumla.keyboardSessionMinutes"

    public init(storedMinutes: Int) {
        self = Self(rawValue: storedMinutes) ?? Self.defaultValue
    }

    public func expiration(from start: Date) -> Date {
        start.addingTimeInterval(TimeInterval(rawValue * 60))
    }
}

public enum KeyboardSessionDestination: Equatable, Sendable {
    case setup, start

    public static let startURL = URL(string: "mumla://keyboard/start")!

    public init?(url: URL) {
        guard url.scheme == "mumla", url.host == "keyboard", url.user == nil,
              url.password == nil, url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        switch url.path {
        case "", "/": self = .setup
        case "/start": self = .start
        default: return nil
        }
    }
}
