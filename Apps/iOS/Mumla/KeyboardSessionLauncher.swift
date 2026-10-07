import AppIntents
import SwiftUI

@MainActor
final class KeyboardSessionLauncher: ObservableObject {
    static let shared = KeyboardSessionLauncher()
    @Published private(set) var requestID: UUID?
    private var requestedAt: Date?

    func requestStart(at now: Date = Date()) {
        requestedAt = now
        requestID = UUID()
    }

    func consumeStart(isForeground: Bool, at now: Date = Date()) -> Bool {
        guard requestID != nil, let requestedAt else { return false }
        guard now.timeIntervalSince(requestedAt) >= 0, now.timeIntervalSince(requestedAt) < 30 else {
            clear()
            return false
        }
        guard isForeground else { return false }
        clear()
        return true
    }

    private func clear() { requestID = nil; requestedAt = nil }
}

// Declared only in the containing app: the shortcut foregrounds Mumla before capture.
struct StartMumlaKeyboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Mumla keyboard"
    static let description = IntentDescription("Open Mumla and start a local keyboard dictation session.")
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult {
        KeyboardSessionLauncher.shared.requestStart()
        return .result()
    }
}

struct MumlaKeyboardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartMumlaKeyboardIntent(),
                    phrases: ["Start \(.applicationName) keyboard", "Starta \(.applicationName) tangentbord"],
                    shortTitle: "Start keyboard", systemImageName: "keyboard")
    }
}
