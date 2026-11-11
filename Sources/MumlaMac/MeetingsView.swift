import AppKit
import MumlaAudio
import MumlaCore
import MumlaUI
import SwiftUI
import UniformTypeIdentifiers

struct MeetingsView: View {
    @ObservedObject var meetings: MeetingCoordinator
    @ObservedObject var app: AppCoordinator
    @State private var query = ""
    @State private var speakerFilter = ""
    @State private var editing: MeetingSegment?
    @State private var editedText = ""
    @State private var editedSpeaker = ""
    @State private var editingMeetingID: UUID?
    @State private var followLive = true
    @State private var deleting: UUID?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let message = meetings.availabilityMessage {
                Label(message, systemImage: "info.circle").font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            }
            if let error = meetings.error {
                HStack(alignment: .top) {
                    Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 12, design: .monospaced))
                    Spacer(minLength: 4)
                    MumlaIconButton("xmark", label: mText("Stäng", "Close")) { meetings.error = nil }
                }.padding(10).mumlaRecess(radius: 6)
            }
            HStack(spacing: 12) {
                Text("\(meetings.records.count) " + mText("möten", "meetings")).font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                Spacer()
                if let id = meetings.activeID {
                    Button { meetings.selectedID = id } label: { Label(mText("Pågående möte", "Current meeting"), systemImage: "record.circle") }
                        .buttonStyle(MumlaKeyStyle()).disabled(meetings.selectedID == id)
                }
                MumlaIconButton("plus", label: mText("Nytt möte", "New meeting")) {
                    meetings.selectedID = nil; meetings.refreshSources(); query = ""; speakerFilter = ""
                }.disabled(meetings.isCapturing)
            }
            if meetings.selected == nil { setup }
            else {
                HStack(alignment: .top, spacing: 14) {
                    library.frame(width: 155)
                    Divider()
                    if let meeting = meetings.selected { transcript(meeting).frame(maxWidth: .infinity, maxHeight: .infinity) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { meetings.refreshSources() }
        .sheet(item: $editing) { segment in
            VStack(alignment: .leading, spacing: 18) {
                Text(mText("Rätta transkript", "Correct transcript")).font(.system(size: 20, weight: .semibold, design: .monospaced))
                TextField(mText("Talare", "Speaker"), text: $editedSpeaker).textFieldStyle(.plain).padding(12).mumlaRecess(radius: 6)
                TextEditor(text: $editedText).scrollContentBackground(.hidden).padding(10).mumlaRecess(radius: 6)
                HStack {
                    Button(mText("Avbryt", "Cancel")) { editing = nil }.buttonStyle(MumlaKeyStyle())
                    Spacer()
                    Button(mText("Spara", "Save")) {
                        if let id = editingMeetingID {
                            do {
                                try meetings.applyCorrection(segment, text: editedText, speakerName: editedSpeaker, meetingID: id)
                                editing = nil
                            } catch { meetings.error = error.localizedDescription }
                        }
                    }.buttonStyle(MumlaKeyStyle()).keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 480, height: 340).background(MumlaStyle.background)
                .font(.system(.body, design: .monospaced))
        }
        .confirmationDialog(mText("Radera mötet och allt ljud?", "Delete meeting and all audio?"), isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button(mText("Radera", "Delete"), role: .destructive) { if let deleting { meetings.delete(deleting) }; deleting = nil }
            }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("STANDBY", systemImage: "record.circle").font(.system(size: 12, weight: .medium, design: .monospaced))
                Spacer()
                Image(systemName: "lock.fill")
                Text("SV / PCM").font(.system(size: 11, design: .monospaced))
            }.foregroundStyle(MumlaStyle.secondary)
            TextField(mText("Mötets namn", "Meeting title"), text: $meetings.title)
                .font(.system(size: 22, design: .monospaced)).textFieldStyle(.plain).padding(14).mumlaRecess(radius: 7)
            HStack {
                Menu {
                    Button(mText("Endast mikrofon", "Microphone only")) { meetings.sourcePID = 0 }
                    Divider()
                    ForEach(meetings.sources) { source in Button(source.name) { meetings.sourcePID = source.id } }
                } label: {
                    Label(meetings.sources.first(where: { $0.id == meetings.sourcePID })?.name ?? mText("Endast mikrofon", "Microphone only"), systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.menuStyle(.borderlessButton).padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44).mumlaSurface(radius: 6)
                MumlaIconButton("arrow.clockwise", label: mText("Uppdatera appar", "Refresh apps")) { meetings.refreshSources() }
                MumlaIconButton("mic", label: mText("Välj mikrofon", "Choose microphone")) { app.openSettings() }
            }
            if meetings.sourcePID != 0 {
                Text(mText("Webbläsarens andra flikar kan också höras.", "Other browser tabs may also be captured."))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            }
            Toggle(mText("Transkribera live", "Live transcription"), isOn: $meetings.liveTranscription).toggleStyle(MumlaSwitchStyle())
            Toggle(mText("Behåll ljud 7 dagar efter transkribering", "Keep audio 7 days after transcription"), isOn: $meetings.keepAudio)
                .toggleStyle(MumlaSwitchStyle()).font(.system(size: 12, design: .monospaced))
            HStack {
                Image(systemName: meetings.speakersInstalled ? "person.2.fill" : "person.2")
                Text(meetings.speakersInstalled ? mText("Talarmodell installerad", "Speaker model installed") : mText("Talarmodell · 45 MB", "Speaker model · 45 MB"))
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                if let fraction = meetings.speakerDownload {
                    ProgressView(value: fraction).frame(width: 90)
                } else if !meetings.speakersInstalled {
                    MumlaIconButton("arrow.down", label: mText("Hämta talarmodell", "Download speaker model")) { meetings.installSpeakers() }
                        .disabled(meetings.isProcessing)
                } else { Image(systemName: "checkmark").foregroundStyle(MumlaStyle.accent) }
            }
            if app.modelDirectory == nil {
                Button { app.installModel() } label: {
                    Label(mText("Hämta svensk språkmodell", "Download Swedish speech model"), systemImage: "arrow.down.circle")
                        .padding(.horizontal, 12).frame(minHeight: 44)
                }
                    .buttonStyle(MumlaKeyStyle()).disabled(app.isInstallingModel)
            }
                }.padding(4)
            }
            Divider()
            HStack {
                Menu {
                    Button(mText("Kopiera samtyckesmeddelande", "Copy consent message")) {
                        copy(mText("Jag vill transkribera vårt möte lokalt med Mumla. Är alla okej med det?", "I'd like to transcribe our meeting locally with Mumla. Is everyone comfortable with that?"))
                    }
                } label: { Image(systemName: "person.crop.circle.badge.checkmark").frame(width: 40, height: 40) }
                    .menuStyle(.borderlessButton).help(mText("Samtycke", "Consent"))
                Spacer()
                Button { Task { await meetings.start() } } label: {
                    Label(meetings.isStarting ? mText("Förbereder", "Preparing") : mText("Spela in möte", "Record meeting"), systemImage: "record.circle.fill")
                        .foregroundStyle(MumlaStyle.recording).padding(.horizontal, 18).frame(height: 48)
                }.buttonStyle(MumlaKeyStyle()).disabled(meetings.isStarting || meetings.isCapturing || meetings.availabilityMessage != nil)
                    .accessibilityIdentifier("meeting.start")
            }
            if !meetings.records.isEmpty {
                Button { meetings.selectedID = meetings.records.first?.id } label: { Label(mText("Sparade möten", "Saved meetings"), systemImage: "clock") }
                    .buttonStyle(MumlaKeyStyle())
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .disabled(meetings.isStarting)
    }

    private var library: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(meetings.records) { meeting in
                    Button { meetings.selectedID = meeting.id; query = ""; speakerFilter = ""; copied = false } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(meeting.title).font(.system(size: 12, weight: .medium, design: .monospaced)).lineLimit(2)
                            Text(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                            Text(meeting.id == meetings.activeID ? (meetings.isPaused ? "PAUSE" : "REC") : MeetingRecord.timestamp(meeting.duration))
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(meeting.id == meetings.activeID ? MumlaStyle.recording : MumlaStyle.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }.buttonStyle(MumlaKeyStyle()).overlay(alignment: .leading) {
                        if meetings.selectedID == meeting.id { Rectangle().fill(MumlaStyle.accent).frame(width: 3).padding(.vertical, 10) }
                    }
                }
            }.padding(.bottom, 4)
        }.scrollClipDisabled()
    }

    private func transcript(_ meeting: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title).font(.system(size: 17, weight: .semibold, design: .monospaced)).lineLimit(2)
                    Text(meeting.sourceName + " · " + MeetingRecord.timestamp(meeting.id == meetings.activeID ? meetings.elapsed : meeting.duration))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                }
                Spacer(minLength: 4)
                Menu {
                    Button(mText("Kopiera text", "Copy text")) { copy(meeting.transcript(timestamps: false)) }
                    Button(mText("Kopiera med talare och tider", "Copy with speakers and times")) { copy(meeting.transcript()) }
                    Button("Markdown") { export(meeting, json: false) }
                    Button("JSON") { export(meeting, json: true) }
                    Button(mText("Radera endast ljud", "Delete audio only"), role: .destructive) { meetings.deleteAudio(meeting.id) }
                        .disabled(meeting.id == meetings.activeID || meeting.audioDeleted)
                    Divider()
                    Button(mText("Radera möte", "Delete meeting"), role: .destructive) { deleting = meeting.id }
                        .disabled(meeting.id == meetings.activeID)
                } label: { Image(systemName: "ellipsis").frame(width: 30, height: 32) }.menuStyle(.borderlessButton)
                    .accessibilityLabel(mText("Mötesåtgärder", "Meeting actions"))
            }
            if meetings.activeID == meeting.id {
                HStack(spacing: 10) {
                    MumlaRecordingLight(recording: !meetings.isPaused)
                    Text(meetings.isPaused ? "PAUSE" : "REC").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Spacer()
                    MumlaIconButton(meetings.isPaused ? "play.fill" : "pause.fill", label: mText("Pausa / fortsätt", "Pause / resume")) { meetings.togglePause() }
                    MumlaIconButton("stop.fill", label: mText("Stoppa och spara", "Stop and save")) { meetings.stop() }
                        .accessibilityIdentifier("meeting.stop")
                }
                meter("MIC", level: meetings.microphoneLevel)
                if !meeting.microphoneOnly { meter("APP", level: meetings.systemLevel) }
            }
            HStack {
                TextField(mText("Sök i transkript", "Search transcript"), text: $query).textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                Menu {
                    Button(mText("Alla talare", "All speakers")) { speakerFilter = "" }
                    ForEach(Array(Set(meeting.segments.map(\.speaker))).sorted(), id: \.self) { speaker in
                        Button(meeting.speakerName(speaker)) { speakerFilter = speaker }
                    }
                } label: { Image(systemName: speakerFilter.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill") }
                    .menuStyle(.borderlessButton).frame(width: 28).accessibilityLabel(mText("Filtrera talare", "Filter speakers"))
            }.padding(10).mumlaRecess(radius: 6)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(meeting.orderedSegments.filter { (speakerFilter.isEmpty || $0.speaker == speakerFilter) && (query.isEmpty || $0.text.localizedCaseInsensitiveContains(query)) }) { segment in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 7) {
                                    Button { meetings.play(segment, meeting: meeting) } label: {
                                        Label(MeetingRecord.timestamp(segment.start), systemImage: meetings.playingSegmentID == segment.id ? "stop.fill" : "play.fill")
                                    }.buttonStyle(.plain).disabled(meeting.audioDeleted || meetings.isCapturing)
                                    Text(meeting.speakerName(segment.speaker)).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button {
                                        editedText = segment.text; editedSpeaker = meeting.speakerName(segment.speaker)
                                        editingMeetingID = meeting.id; editing = segment
                                    } label: { Image(systemName: "pencil").frame(width: 24, height: 24) }
                                        .buttonStyle(.plain).help(mText("Rätta text eller talare", "Correct text or speaker"))
                                }.font(.system(size: 11, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                                Text(segment.text).font(.system(size: 14, design: .monospaced)).lineSpacing(4).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.id(segment.id)
                        }
                        Color.clear.frame(height: 1).id("live-end")
                    }.padding(.vertical, 6)
                    if meeting.segments.isEmpty {
                        Text(meeting.audioDeleted ? mText("Ljudet har raderats.", "Audio has been deleted.")
                             : meetings.activeID == meeting.id ? mText("Lyssnar…", "Listening…") : mText("Inspelning sparad", "Recording saved"))
                            .font(.system(size: 13, design: .monospaced)).foregroundStyle(MumlaStyle.secondary).padding(.vertical, 24)
                    }
                }.onChange(of: meeting.segments.count) { _, _ in if followLive { proxy.scrollTo("live-end", anchor: .bottom) } }
            }.accessibilityIdentifier("meeting.transcript")
            Divider()
            HStack(spacing: 10) {
                Text(status(meeting)).font(.system(size: 10, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                Spacer(minLength: 0)
                if meetings.activeID == meeting.id {
                    Toggle(mText("Följ", "Follow"), isOn: $followLive).toggleStyle(MumlaSwitchStyle()).font(.system(size: 11, design: .monospaced))
                }
                if meeting.processing == .processing || meeting.processing == .live {
                    MumlaIconButton("pause.fill", label: mText("Pausa transkribering", "Pause transcription")) { meetings.cancelProcessing(meeting.id) }
                } else if meeting.processedChunkIDs.count < meeting.chunks.count && !meeting.audioDeleted {
                    MumlaIconButton("waveform", label: mText("Transkribera", "Transcribe")) { meetings.transcribe(meeting.id) }
                }
                MumlaIconButton(copied ? "checkmark" : "doc.on.doc", label: mText("Kopiera transkript", "Copy transcript")) { copy(meeting.transcript()) }
                    .disabled(meeting.segments.isEmpty)
            }
        }
    }

    private func meter(_ label: String, level: Double) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 10, design: .monospaced)).frame(width: 30, alignment: .leading)
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(0..<28) { index in Rectangle().fill(!meetings.isPaused && Double(index) / 28 < level ? MumlaStyle.accent : MumlaStyle.meterOff) }
                }.frame(width: geometry.size.width, height: 8)
            }.frame(height: 8)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityValue("\(Int(level * 100))%")
    }

    private func status(_ meeting: MeetingRecord) -> String {
        if meeting.audioDeleted { return mText("Ljud raderat", "Audio deleted") }
        if meeting.speakerLabelsUnavailable == true { return mText("Talarmodell saknas · ljudkällor visas", "Speaker labels unavailable · showing sources") }
        if meeting.processing == .ready { return mText("Klart · på den här Macen", "Ready · on this Mac") }
        let total = meeting.chunks.reduce(0) { $0 + $1.duration }
        let done = meeting.chunks.filter { meeting.processedChunkIDs.contains($0.id) }.reduce(0) { $0 + $1.duration }
        return "\(MeetingRecord.timestamp(done)) / \(MeetingRecord.timestamp(total))"
    }

    private func copy(_ text: String) { NSPasteboard.general.clearContents(); copied = NSPasteboard.general.setString(text, forType: .string) }
    private func export(_ meeting: MeetingRecord, json: Bool) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [json ? .json : UTType(filenameExtension: "md")!]
        panel.nameFieldStringValue = "Mumla-" + meeting.createdAt.formatted(.iso8601.year().month().day()) + (json ? ".json" : ".md")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try (json ? meeting.exportJSON() : Data(meeting.markdown.utf8)).write(to: url, options: .atomic) }
        catch { meetings.error = error.localizedDescription }
    }
}
