import SwiftUI

@main
struct MumlaApp: App {
    @StateObject private var session = DictationSession()
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--ui-testing") && CommandLine.arguments.contains("--keyboard-preview") {
                KeyboardPreviewHarness()
            } else if CommandLine.arguments.contains("--ui-testing") && CommandLine.arguments.contains("--keyboard-host") {
                KeyboardHostHarness()
            } else { MumlaHomeView(session: session) }
            #else
            MumlaHomeView(session: session)
            #endif
        }
    }
}
