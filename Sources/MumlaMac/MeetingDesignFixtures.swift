#if DEBUG
import Foundation
import MumlaAudio
import MumlaCore

@MainActor
enum MeetingDesignFixtures {
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
}

final class MeetingUICapture: MeetingCapturing {
    func start(store: MeetingStore, meetingID: UUID, microphoneUID: String?, source: MeetingAudioSource?, offset: TimeInterval,
               onChunk: @escaping @Sendable () -> Void, onFailure: @escaping @Sendable (String) -> Void) throws {}
    func stop() {}
    func level(_ track: MeetingTrack) -> Double { 0.3 }
}
#endif
