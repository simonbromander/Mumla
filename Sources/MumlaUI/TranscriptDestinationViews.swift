import MumlaCore
import SwiftUI

public struct TranscriptDestinationSettings: View {
    @ObservedObject private var controller: TranscriptDestinationController
    @State private var name = ""
    @State private var address = ""
    @State private var token = ""
    @State private var removeConfirmation = false

    public init(controller: TranscriptDestinationController) { self.controller = controller }

    private var changed: Bool {
        name != (controller.destination?.name ?? "") || address != (controller.destination?.url.absoluteString ?? "") || !token.isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(mText("Sändningsdestination", "Send destination"), systemImage: "paperplane")
                .font(.system(.headline, design: .monospaced)).accessibilityAddTraits(.isHeader)
            MumlaTextField(mText("Namn", "Name"), text: $name).accessibilityIdentifier("destination.name")
            MumlaTextField(mText("HTTPS-adress", "HTTPS address"), text: $address).accessibilityIdentifier("destination.url")
            VStack(alignment: .leading, spacing: 8) {
                Text("Token").font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                SecureField(controller.destination == nil ? "Token" : mText("Ny token (tomt behåller befintlig)", "New token (blank keeps existing)"), text: $token)
                    .textFieldStyle(.plain).padding(16).mumlaRecess(radius: 8).accessibilityIdentifier("destination.token")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions }
                VStack(alignment: .leading, spacing: 12) { actions }
            }
            if let status = controller.settingsStatus {
                Text(status).font(.system(.caption, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("destination.status")
            }
        }
        .autocorrectionDisabled()
        #if os(iOS)
        .textInputAutocapitalization(.never)
        #endif
        .disabled(controller.isSending)
        .onAppear { reload() }
        .onDisappear { token = "" }
        .confirmationDialog(mText("Ta bort destinationen och dess token?", "Remove the destination and its token?"), isPresented: $removeConfirmation, titleVisibility: .visible) {
            Button(mText("Ta bort", "Remove"), role: .destructive) { controller.remove(); token = ""; reload() }
        }
    }

    @ViewBuilder private var actions: some View {
        Button {
            if controller.save(name: name, address: address, token: token) { token = ""; reload() }
        } label: { Label(mText("Spara", "Save"), systemImage: "checkmark").padding(12) }
            .buttonStyle(MumlaKeyStyle()).disabled(!changed).accessibilityIdentifier("destination.save")
        Button { Task { await controller.test() } } label: {
            Label(mText("Testa", "Test"), systemImage: "paperplane").padding(12)
        }.buttonStyle(MumlaKeyStyle()).disabled(controller.destination == nil || changed).accessibilityIdentifier("destination.test")
        Button { removeConfirmation = true } label: { Label(mText("Ta bort", "Remove"), systemImage: "trash").padding(12) }
            .buttonStyle(MumlaKeyStyle()).disabled(controller.destination == nil).accessibilityIdentifier("destination.remove")
    }

    private func reload() { name = controller.destination?.name ?? ""; address = controller.destination?.url.absoluteString ?? "" }
}

public struct TranscriptSendAction: View {
    @ObservedObject private var controller: TranscriptDestinationController
    private let id: UUID
    private let transcript: OutgoingTranscript?
    private let sentAt: Date?
    private let persist: (Date) throws -> Void
    @State private var pending: ApprovedSend?
    private struct ApprovedSend: Identifiable {
        let id = UUID()
        let transcript: OutgoingTranscript
        let destination: TranscriptDestination
    }

    public init(controller: TranscriptDestinationController, id: UUID, transcript: OutgoingTranscript?, sentAt: Date?,
                persistReceipt: @escaping (Date) throws -> Void) {
        self.controller = controller; self.id = id; self.transcript = transcript; self.sentAt = sentAt; persist = persistReceipt
    }

    public var body: some View {
        if let destination = controller.destination {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    guard let transcript else { return }
                    if controller.wasSent(id, sentAt: sentAt) { pending = ApprovedSend(transcript: transcript, destination: destination) }
                    else { send(transcript, destination: destination) }
                } label: {
                    Label(mText("Skicka till ", "Send to ") + destination.name, systemImage: controller.isSending ? "hourglass" : "paperplane")
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true).padding(12)
                }.buttonStyle(MumlaKeyStyle()).disabled(controller.isSending || transcript == nil)
                    .accessibilityIdentifier("transcript.send")
                if let status = controller.results[id] {
                    Text(status).font(.system(.caption, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("transcript.send.status")
                } else if let sentAt {
                    Text(mText("Senast skickat: ", "Last sent: ") + sentAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                }
            }
            .alert(item: $pending) { approved in
                Alert(title: Text(mText("Skicka igen till ", "Send again to ") + approved.destination.name + "?"),
                      message: Text(mText("Det här transkriptet har redan skickats. Ett nytt exemplar kan skapas.", "This transcript was already sent. Another item may be created.")),
                      primaryButton: .default(Text(mText("Skicka igen", "Send again"))) {
                          guard transcript == approved.transcript else { return }
                          send(approved.transcript, destination: approved.destination)
                      }, secondaryButton: .cancel())
            }
        }
    }

    private func send(_ value: OutgoingTranscript, destination: TranscriptDestination) {
        Task { await controller.send(value, id: id, approvedDestination: destination, persistReceipt: persist) }
    }
}
