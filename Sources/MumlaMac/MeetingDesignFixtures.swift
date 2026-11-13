#if DEBUG
import Foundation
import MumlaAudio
import MumlaCore

@MainActor
enum MeetingDesignFixtures {
    static func suggestion(long: Bool = false) -> MeetingSuggestion {
        MeetingSuggestion(candidate: MeetingDetectionCandidate(id: UUID(), app: DetectedMeetingApp(id: ProcessInfo.processInfo.processIdentifier,
            bundleID: "app.mumla.fixture.meeting", kind: .teams), expiresAt: Date().addingTimeInterval(60)),
            title: long ? String(repeating: "Planering och återkoppling från produktteamet. ", count: 4) : "Produktgenomgång")
    }

    static func detection(start: @escaping @MainActor (DetectedMeetingApp, String?) async -> Void) -> MeetingDetectionCoordinator {
        var date = Date()
        let monitor = MeetingUIActivityMonitor()
        let model = MeetingDetectionCoordinator(monitor: monitor, calendar: MeetingUICalendar(), now: { date })
        model.onStart = start
        model.configure(enabled: true, useCalendar: true)
        date.addTimeInterval(2); model.refresh()
        return model
    }

    static func seed(_ model: MeetingCoordinator, long: Bool = false) throws -> MeetingRecord {
        let record = MeetingRecord(title: long ? "Planering av nästa produktversion och återkoppling från användare" : "Produktgenomgång",
            sourceName: long ? "Mötesapp med ett långt namn för produktteamets videokonferenser" : "Meeting app", microphoneOnly: false,
            createdAt: Date(timeIntervalSince1970: 1_790_602_260))
        try model.store.create(record)
        let result = try model.store.update(record.id) {
            $0.capture = .saved; $0.processing = .ready; $0.duration = 1485
            $0.speakerNames = ["system-0": long ? "Alexandra Andersson - Produkt och plattformsutveckling" : "Anna", "microphone": "Me"]
            $0.segments = [
                MeetingSegment(id: "example-0", chunkID: "example", track: .microphone, start: 12, end: 20, speaker: "microphone", text: "Vi börjar med inspelningen. Ljudet och transkriptet stannar på den här Macen."),
                MeetingSegment(id: "example-1", chunkID: "example", track: .system, start: 21, end: 29, speaker: "system-0", text: "Bra. Jag vill kunna gå tillbaka till det vi faktiskt sa, med tydliga tider och talare."),
                MeetingSegment(id: "example-2", chunkID: "example", track: .microphone, start: 31, end: 38, speaker: "microphone", text: "Då testar vi både hörlurar och högtalare innan vi släpper nästa version.")]
        }
        model.reload(); model.selectedID = record.id
        return result
    }

    static func seedLibrary(_ model: MeetingCoordinator) throws {
        let template = try seed(model)
        let titles = ["Produktgenomgång", "Design review", "Planering av nästa produktversion och återkoppling från användare",
                      "Weekly planning", "Research interviews", "Release checklist"]
        for (index, title) in titles.enumerated() {
            var record = template
            record.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
            record.title = title
            record.createdAt = Calendar.current.date(byAdding: .day, value: -(index / 2), to: Date())!
                .addingTimeInterval(-Double(index % 2) * 3600)
            record.duration = Double(1485 + index * 600)
            if index == 1 { record.capture = .interrupted }
            if index == 3 { record.segments = []; record.processing = .pending }
            _ = try model.store.create(record)
        }
        try model.store.delete(template.id)
        model.reload(); model.selectedID = nil
    }
}

final class MeetingUICapture: MeetingCapturing {
    func start(store: MeetingStore, meetingID: UUID, microphoneUID: String?, source: MeetingAudioSource?, offset: TimeInterval,
               onChunk: @escaping @Sendable () -> Void, onFailure: @escaping @Sendable (String) -> Void) throws {}
    func stop() {}
    func level(_ track: MeetingTrack) -> Double { 0.3 }
}

@MainActor
private final class MeetingUIActivityMonitor: MeetingActivityMonitoring {
    var onChange: (([DetectedMeetingApp], Bool) -> Void)?
    func start() { refresh() }
    func refresh() { onChange?([MeetingDesignFixtures.suggestion().candidate.app], true) }
    func stop() {}
}

@MainActor
private final class MeetingUICalendar: MeetingCalendarProviding {
    var access: MeetingCalendarAccess { .allowed }
    func requestAccess() async -> Bool { true }
    func title(for app: MeetingAppKind, now: Date) -> String? { "Produktgenomgång" }
}
#endif
