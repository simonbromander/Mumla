import ActivityKit
import AppIntents
import MumlaCore

struct MumlaKeyboardActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var recordingStartedAt: Date?
        var expiresAt: Date
    }
    var sessionID: UUID
}

struct EndMumlaKeyboardSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Mumla keyboard session"
    static let openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        if let store = KeyboardSessionStore.shared(), let id = try store.snapshot().sessionID {
            try store.send(KeyboardSessionCommand(sessionID: id, action: .end))
        }
        return .result()
    }
}
