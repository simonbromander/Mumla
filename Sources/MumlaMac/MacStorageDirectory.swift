import Foundation
import MumlaAudio

enum MacStorageDirectory {
    static func resolve(fileManager: FileManager = .default) -> URL {
        let directory = ModelPathResolver.appSupportDirectory(fileManager: fileManager)
        guard Bundle.main.object(forInfoDictionaryKey: "MumlaDistribution") as? String == "direct" else { return directory }
        let container = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.mumla.app/Data/Library/Application Support/Mumla", isDirectory: true)
        return preferredDirectory(current: directory, previous: container, fileManager: fileManager)
    }

    static func preferredDirectory(current: URL, previous: URL, fileManager: FileManager = .default) -> URL {
        // Adopt the app's existing store in place; never overwrite it or duplicate large models.
        if hasData(at: current, fileManager: fileManager) { return current }
        if hasData(at: previous, fileManager: fileManager) { return previous }
        return current
    }

    private static func hasData(at directory: URL, fileManager: FileManager) -> Bool {
        ["history.json", "dictionary.json", "settings.json", "Models", "Downloads"].contains {
            fileManager.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
    }
}
