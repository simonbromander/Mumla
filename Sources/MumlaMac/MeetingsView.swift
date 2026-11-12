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
    @State private var followLive = true
    @State private var copied = false
    @State private var libraryOpen = false
    @State private var sourcesOpen = false
    @State private var speakersOpen = false
    @State private var actionsOpen = false
    @State private var dialog: MeetingDialog?

    static func showsLibrary(at width: CGFloat) -> Bool { width >= 720 }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 14) {
                if let message = meetings.availabilityMessage { notice(message, symbol: "info.circle") }
                if let error = meetings.error {
                    HStack(alignment: .top, spacing: 12) {
                        notice(error, symbol: "exclamationmark.triangle")
                        Spacer(minLength: 0)
                        MumlaIconButton("xmark", label: mText("Stäng", "Close")) { meetings.error = nil }
                    }.padding(12).mumlaRecess(radius: 8)
                }
                toolbar
                if meetings.selected == nil { setup }
                else {
                    HStack(alignment: .top, spacing: 20) {
                        if Self.showsLibrary(at: geometry.size.width) {
                            library.frame(width: 200)
                            Divider()
                        }
                        if let meeting = meetings.selected { transcript(meeting) }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { meetings.refreshSources() }
        .onChange(of: meetings.selectedID) { _, _ in query = ""; speakerFilter = ""; copied = false }
        .sheet(item: $dialog) { item in
            switch item {
            case .correction(let meetingID, let segment, let speaker):
                MeetingCorrectionSheet(segment: segment, speaker: speaker) { text, name in
                    try meetings.applyCorrection(segment, text: text, speakerName: name, meetingID: meetingID)
                }
            case .deletion(let meeting, let audioOnly):
                MeetingDeletionSheet(meeting: meeting, audioOnly: audioOnly) {
                    guard meetings.activeID != meeting.id else { return mText("Stoppa inspelningen först.", "Stop recording first.") }
                    meetings.error = nil
                    if audioOnly { meetings.deleteAudio(meeting.id) } else { meetings.delete(meeting.id) }
                    return meetings.error
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("\(meetings.records.count) " + (meetings.records.count == 1 ? mText("möte", "meeting") : mText("möten", "meetings")))
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            Spacer(minLength: 0)
            if let id = meetings.activeID {
                MumlaIconButton("record.circle", label: mText("Pågående möte", "Current meeting")) { meetings.selectedID = id }
                    .disabled(meetings.selectedID == id)
            }
            MumlaIconButton("tray.full", label: mText("Sparade möten", "Saved meetings")) { libraryOpen.toggle() }
                .disabled(meetings.records.isEmpty).accessibilityIdentifier("meeting.library")
                .popover(isPresented: $libraryOpen, arrowEdge: .trailing) {
                    MeetingPopover(title: mText("Sparade möten", "Saved meetings")) { library.frame(height: 360) }
                }
            MumlaIconButton("plus", label: mText("Nytt möte", "New meeting")) {
                meetings.selectedID = nil; meetings.refreshSources()
            }.disabled(meetings.isCapturing).accessibilityIdentifier("meeting.new")
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("STANDBY", systemImage: "record.circle")
                        Spacer()
                        Label("SV / PCM", systemImage: "lock.fill")
                    }.font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    TextField(mText("Mötets namn", "Meeting title"), text: $meetings.title, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 18, design: .monospaced))
                        .lineLimit(1...4).padding(16).mumlaRecess(radius: 8).accessibilityIdentifier("meeting.title")
                        .accessibilityLabel(mText("Mötets namn", "Meeting title"))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Button { sourcesOpen.toggle() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: meetings.sourcePID == 0 ? "mic" : "speaker.wave.2")
                                    Text(meetings.sourcePID == 0 ? mText("Endast mikrofon", "Microphone only") : meetings.sources.first(where: { $0.id == meetings.sourcePID })?.name ?? mText("Appen är inte tillgänglig", "App unavailable"))
                                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.down").font(.system(size: 11))
                                }.padding(14).frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(MumlaKeyStyle(radius: 8)).accessibilityIdentifier("meeting.source")
                                .popover(isPresented: $sourcesOpen) {
                                    MeetingPopover(title: mText("Ljudkälla", "Audio source")) {
                                        ScrollView {
                                            VStack(spacing: 8) {
                                                choice(mText("Endast mikrofon", "Microphone only"), symbol: "mic", selected: meetings.sourcePID == 0) {
                                                    meetings.sourcePID = 0; sourcesOpen = false
                                                }
                                                ForEach(meetings.sources) { source in
                                                    choice(source.name, symbol: "speaker.wave.2", selected: meetings.sourcePID == source.id) {
                                                        meetings.sourcePID = source.id; sourcesOpen = false
                                                    }
                                                }
                                            }.padding(4)
                                        }.frame(maxHeight: 320)
                                    }
                                }
                            MumlaIconButton("arrow.clockwise", label: mText("Uppdatera appar", "Refresh apps")) { meetings.refreshSources() }
                            MumlaIconButton("mic", label: mText("Välj mikrofon", "Choose microphone")) { app.openSettings() }
                        }
                        if meetings.sourcePID != 0 {
                            notice(mText("Webbläsarens andra flikar kan också höras.", "Other browser tabs may also be captured."), symbol: "info.circle")
                        }
                    }
                    Divider()
                    Toggle(isOn: $meetings.liveTranscription) {
                        Text(mText("Transkribera live", "Live transcription")).fixedSize(horizontal: false, vertical: true)
                    }.toggleStyle(MumlaSwitchStyle()).font(.system(size: 13, design: .monospaced))
                    Toggle(isOn: $meetings.keepAudio) {
                        Text(mText("Behåll ljud i 7 dagar", "Keep audio for 7 days"))
                            .fixedSize(horizontal: false, vertical: true)
                    }.toggleStyle(MumlaSwitchStyle()).font(.system(size: 13, design: .monospaced))
                        .help(mText("Behåll ljud 7 dagar efter transkribering", "Keep audio 7 days after transcription"))
                        .accessibilityLabel(mText("Behåll ljud 7 dagar efter transkribering", "Keep audio 7 days after transcription"))
                    Divider()
                    MeetingDetectionSettingsView(app: app, detection: app.meetingDetection)
                    Divider()
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: meetings.speakersInstalled ? "person.2.fill" : "person.2").padding(.top, 3)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(meetings.speakersInstalled ? mText("Talarmodell installerad", "Speaker model installed") : mText("Talarmodell · 45 MB", "Speaker model · 45 MB"))
                                .font(.system(size: 13, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                            if let fraction = meetings.speakerDownload {
                                MumlaDownloadGauge(fraction: fraction)
                                Text("\(Int(fraction * 100)) %").font(.system(size: 12, design: .monospaced)).monospacedDigit()
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if meetings.speakerDownload == nil && !meetings.speakersInstalled {
                            MumlaIconButton("arrow.down", label: mText("Hämta talarmodell", "Download speaker model")) { meetings.installSpeakers() }
                                .disabled(meetings.isProcessing)
                        } else if meetings.speakersInstalled { Image(systemName: "checkmark").foregroundStyle(MumlaStyle.accent) }
                    }
                    if app.modelDirectory == nil {
                        choice(mText("Hämta svensk språkmodell", "Download Swedish speech model"), symbol: "arrow.down.circle", selected: false) { app.installModel() }
                            .disabled(app.isInstallingModel)
                    }
                }.padding(4).padding(.bottom, 12)
            }
            Divider()
            HStack(spacing: 12) {
                MumlaIconButton(copied ? "checkmark" : "person.crop.circle.badge.checkmark", label: mText("Kopiera samtyckesmeddelande", "Copy consent message")) {
                    copy(mText("Jag vill transkribera vårt möte lokalt med Mumla. Är alla okej med det?", "I'd like to transcribe our meeting locally with Mumla. Is everyone comfortable with that?"))
                }
                Spacer(minLength: 0)
                Button { Task { await meetings.start() } } label: {
                    Label(meetings.isStarting ? mText("Förbereder", "Preparing") : mText("Spela in möte", "Record meeting"), systemImage: "record.circle.fill")
                        .foregroundStyle(MumlaStyle.recording).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                }.buttonStyle(MumlaKeyStyle(radius: 8))
                    .disabled(meetings.isCapturing || meetings.availabilityMessage != nil).accessibilityIdentifier("meeting.start")
            }
        }.disabled(meetings.isStarting)
    }

    private var library: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(meetings.records) { meeting in
                    Button { meetings.selectedID = meeting.id; libraryOpen = false } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(meeting.title).font(.system(size: 13, weight: .medium, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(meeting.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                                Spacer(minLength: 4)
                                Text(meeting.id == meetings.activeID ? (meetings.isPaused ? "PAUSE" : "REC") : MeetingRecord.timestamp(meeting.duration))
                                    .foregroundStyle(meeting.id == meetings.activeID ? MumlaStyle.recording : MumlaStyle.secondary)
                            }.monospacedDigit()
                        }.font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    }.buttonStyle(MumlaKeyStyle(radius: 8))
                        .overlay(alignment: .leading) {
                            if meetings.selectedID == meeting.id { Rectangle().fill(MumlaStyle.activeKey).frame(width: 3).padding(.vertical, 12) }
                        }.accessibilityAddTraits(meetings.selectedID == meeting.id ? .isSelected : [])
                }
            }.padding(4)
        }.accessibilityIdentifier("meeting.library.list")
    }

    private func transcript(_ meeting: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(MumlaStyle.secondary)
                    TextField(mText("Sök i transkript", "Search transcript"), text: $query)
                        .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced)).accessibilityIdentifier("meeting.search")
                }.padding(12).frame(minHeight: 44).mumlaRecess(radius: 8)
                MumlaIconButton(speakerFilter.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill", label: mText("Filtrera talare", "Filter speakers")) { speakersOpen.toggle() }
                    .accessibilityIdentifier("meeting.speakers")
                    .popover(isPresented: $speakersOpen, arrowEdge: .trailing) {
                        MeetingPopover(title: mText("Talare", "Speakers")) {
                            ScrollView {
                                VStack(spacing: 8) {
                                    choice(mText("Alla talare", "All speakers"), symbol: "person.2", selected: speakerFilter.isEmpty) { speakerFilter = ""; speakersOpen = false }
                                    ForEach(Array(Set(meeting.segments.map(\.speaker))).sorted(), id: \.self) { speaker in
                                        choice(meeting.speakerName(speaker), symbol: "person", selected: speakerFilter == speaker) { speakerFilter = speaker; speakersOpen = false }
                                    }
                                }.padding(4)
                            }.frame(maxHeight: 280)
                        }
                    }
                MumlaIconButton("ellipsis", label: mText("Mötesåtgärder", "Meeting actions")) { actionsOpen.toggle() }
                    .accessibilityIdentifier("meeting.actions")
                    .popover(isPresented: $actionsOpen, arrowEdge: .trailing) { actions(meeting) }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(meeting.title).font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("meeting.document.title")
                            Text(meeting.sourceName + " · " + MeetingRecord.timestamp(meeting.id == meetings.activeID ? meetings.elapsed : meeting.duration))
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if meetings.activeID == meeting.id {
                            MeetingRecordingReadout(paused: meetings.isPaused, elapsed: meetings.elapsed,
                                microphone: meetings.microphoneLevel, system: meeting.microphoneOnly ? nil : meetings.systemLevel)
                        }
                        if !speakerFilter.isEmpty {
                            Label(meeting.speakerName(speakerFilter), systemImage: "person")
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        let segments = meeting.orderedSegments.filter { (speakerFilter.isEmpty || $0.speaker == speakerFilter) && (query.isEmpty || $0.text.localizedCaseInsensitiveContains(query)) }
                        LazyVStack(alignment: .leading, spacing: 22) {
                            ForEach(segments) { segment in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Button { meetings.play(segment, meeting: meeting) } label: {
                                            Label(MeetingRecord.timestamp(segment.start), systemImage: meetings.playingSegmentID == segment.id ? "stop.fill" : "play.fill")
                                                .font(.system(size: 12, design: .monospaced)).monospacedDigit().padding(10)
                                        }.buttonStyle(MumlaKeyStyle(radius: 6)).disabled(meeting.audioDeleted || meetings.isCapturing)
                                        Text(meeting.speakerName(segment.speaker)).font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(MumlaStyle.secondary).fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                                        MumlaIconButton("pencil", label: mText("Rätta text eller talare", "Correct text or speaker")) {
                                            dialog = .correction(meetingID: meeting.id, segment: segment, speaker: meeting.speakerName(segment.speaker))
                                        }.accessibilityIdentifier("meeting.correct.\(segment.id)")
                                    }
                                    Text(segment.text).font(.system(size: 14, design: .monospaced)).lineSpacing(5)
                                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .accessibilityIdentifier("meeting.passage.\(segment.id)")
                                }.id(segment.id)
                            }
                            if segments.isEmpty {
                                notice(emptyMessage(meeting), symbol: "waveform").padding(.vertical, 20)
                            }
                            Color.clear.frame(height: 1).id("live-end")
                        }
                    }.padding(4).padding(.bottom, 8)
                }.onChange(of: meeting.segments.count) { _, _ in
                    if followLive && meetings.activeID == meeting.id && query.isEmpty && speakerFilter.isEmpty { proxy.scrollTo("live-end", anchor: .bottom) }
                }
            }.accessibilityIdentifier("meeting.transcript")
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statusLabel(meeting).fixedSize()
                    Spacer(minLength: 0)
                    transcriptControls(meeting).fixedSize()
                }
                VStack(alignment: .leading, spacing: 10) {
                    statusLabel(meeting).fixedSize(horizontal: false, vertical: true)
                    transcriptControls(meeting).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusLabel(_ meeting: MeetingRecord) -> some View {
        Text(status(meeting)).font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            .accessibilityIdentifier("meeting.status")
    }

    private func transcriptControls(_ meeting: MeetingRecord) -> some View {
        HStack(spacing: 10) {
            if meetings.activeID == meeting.id {
                Toggle(mText("Följ", "Follow"), isOn: $followLive).toggleStyle(MumlaSwitchStyle())
                    .font(.system(size: 12, design: .monospaced)).fixedSize()
                Spacer(minLength: 0)
                MumlaIconButton(meetings.isPaused ? "play.fill" : "pause.fill", label: meetings.isPaused ? mText("Fortsätt inspelning", "Resume recording") : mText("Pausa inspelning", "Pause recording")) { meetings.togglePause() }
                MumlaIconButton("stop.fill", label: mText("Stoppa och spara", "Stop and save")) { meetings.stop() }.accessibilityIdentifier("meeting.stop")
            } else {
                Spacer(minLength: 0)
                if meeting.processing == .processing || meeting.processing == .live {
                    MumlaIconButton("pause.fill", label: mText("Pausa transkribering", "Pause transcription")) { meetings.cancelProcessing(meeting.id) }
                } else if meeting.processedChunkIDs.count < meeting.chunks.count && !meeting.audioDeleted {
                    MumlaIconButton("waveform", label: mText("Transkribera", "Transcribe")) { meetings.transcribe(meeting.id) }
                }
            }
            MumlaIconButton(copied ? "checkmark" : "doc.on.doc", label: mText("Kopiera transkript", "Copy transcript")) { copy(meeting.transcript()) }.disabled(meeting.segments.isEmpty)
        }
    }

    private func emptyMessage(_ meeting: MeetingRecord) -> String {
        if !query.isEmpty || !speakerFilter.isEmpty { return mText("Inga matchande avsnitt", "No matching passages") }
        if meeting.audioDeleted { return mText("Ljudet har raderats.", "Audio has been deleted.") }
        if meetings.activeID == meeting.id { return meetings.isPaused ? mText("Inspelning pausad", "Recording paused") : mText("Lyssnar…", "Listening…") }
        return mText("Inspelning sparad", "Recording saved")
    }

    private func actions(_ meeting: MeetingRecord) -> some View {
        MeetingPopover(title: mText("Mötesåtgärder", "Meeting actions")) {
            VStack(spacing: 10) {
                choice(mText("Kopiera text", "Copy text"), symbol: "doc.on.doc", selected: false) { copy(meeting.transcript(timestamps: false)); actionsOpen = false }.disabled(meeting.segments.isEmpty)
                choice(mText("Kopiera med talare och tider", "Copy with speakers and times"), symbol: "text.badge.plus", selected: false) { copy(meeting.transcript()); actionsOpen = false }.disabled(meeting.segments.isEmpty)
                HStack(spacing: 10) {
                    choice("Markdown", symbol: "square.and.arrow.up", selected: false) { actionsOpen = false; export(meeting, json: false) }
                    choice("JSON", symbol: "square.and.arrow.up", selected: false) { actionsOpen = false; export(meeting, json: true) }
                }
                Divider().padding(.vertical, 4)
                choice(mText("Radera endast ljud", "Delete audio only"), symbol: "waveform.slash", selected: false) { actionsOpen = false; dialog = .deletion(meeting: meeting, audioOnly: true) }.disabled(meeting.id == meetings.activeID || meeting.audioDeleted)
                choice(mText("Radera möte", "Delete meeting"), symbol: "trash", selected: false) { actionsOpen = false; dialog = .deletion(meeting: meeting, audioOnly: false) }.disabled(meeting.id == meetings.activeID)
            }
        }
    }

    private func choice(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol).frame(width: 18)
                Text(title).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                if selected { Image(systemName: "checkmark").foregroundStyle(MumlaStyle.accent) }
            }.font(.system(size: 13, design: .monospaced)).padding(14).frame(minHeight: 44)
        }.buttonStyle(MumlaKeyStyle(radius: 8)).accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.system(size: 13, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func status(_ meeting: MeetingRecord) -> String {
        if meeting.audioDeleted { return mText("Ljud raderat", "Audio deleted") }
        if meeting.speakerLabelsUnavailable == true { return mText("Talarmodell saknas · ljudkällor visas", "Speaker labels unavailable · showing sources") }
        if meeting.processing == .ready { return mText("Klart · på den här Macen", "Ready · on this Mac") }
        if meetings.activeID == meeting.id { return meetings.isPaused ? mText("Inspelning pausad", "Recording paused") : mText("Spelar in · på den här Macen", "Recording · on this Mac") }
        if meeting.processing == .failed { return mText("Transkribering avbruten · ljudet är sparat", "Transcription interrupted · audio is saved") }
        let total = meeting.chunks.reduce(0) { $0 + $1.duration }
        let done = meeting.chunks.filter { meeting.processedChunkIDs.contains($0.id) }.reduce(0) { $0 + $1.duration }
        return mText("Transkriberat ", "Transcribed ") + "\(MeetingRecord.timestamp(done)) / \(MeetingRecord.timestamp(total))"
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
