import Foundation
import MumlaCore
import WatchConnectivity

/// The paired device receives audio and text only after Watch-local transcription.
final class VoiceNoteConnectivity: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let store: VoiceNoteStore
    private let changed: @Sendable (String?) -> Void
    private let session: WCSession?

    init(store: VoiceNoteStore, changed: @escaping @Sendable (String?) -> Void) {
        self.store = store
        self.changed = changed
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func sendPending() {
        #if os(watchOS)
        guard let session, session.activationState == .activated, session.isCompanionAppInstalled else { return }
        do {
            for note in try store.load() where !note.delivered && note.deliveryID != nil {
                let deliveryID = note.deliveryID!
                guard !session.outstandingFileTransfers.contains(where: { $0.file.metadata?["deliveryID"] as? String == deliveryID }) else { continue }
                session.transferFile(store.audioURL(for: note.id), metadata: [
                    "voiceNoteVersion": 1, "note": try note.transferData(), "deliveryID": deliveryID
                ])
            }
        } catch { changed(error.localizedDescription) }
        #endif
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error { changed(error.localizedDescription) }
        else { sendPending(); changed(nil) }
    }

    func sessionReachabilityDidChange(_ session: WCSession) { sendPending() }
    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) { sendPending() }
    #endif

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        #if os(iOS)
        guard file.metadata?["voiceNoteVersion"] as? Int == 1,
              let data = file.metadata?["note"] as? Data,
              let deliveryID = file.metadata?["deliveryID"] as? String else { return }
        do {
            let note: VoiceNote
            do { note = try store.receive(data, audio: file.fileURL, deliveryID: deliveryID) }
            catch VoiceNoteError.deleted {
                // An already-deleted note must not return after a duplicate delivery.
                guard data.count <= 32_000 else { throw VoiceNoteError.invalidNote }
                note = try JSONDecoder().decode(VoiceNote.self, from: data)
                try note.validate(requireTranscript: true)
            }
            guard note.deliveryID == deliveryID else { throw VoiceNoteError.invalidNote }
            session.transferUserInfo(["voiceNoteAck": note.id.uuidString, "deliveryID": deliveryID])
            changed(nil)
        } catch { changed(error.localizedDescription) }
        #endif
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        #if os(watchOS)
        guard let rawID = userInfo["voiceNoteAck"] as? String, let id = UUID(uuidString: rawID),
              let deliveryID = userInfo["deliveryID"] as? String else { return }
        do { try store.acknowledge(id: id, deliveryID: deliveryID); changed(nil) }
        catch { changed(error.localizedDescription) }
        #endif
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        // Finishing a transfer is not a durable receipt. Keep the recording until the phone acknowledges it.
        if let error { changed(error.localizedDescription) }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
