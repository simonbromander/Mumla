import MumlaCore
import MumlaUI
import SwiftUI

struct MeetingLibraryView: View {
    @MumlaTheme private var palette
    let records: [MeetingRecord]
    let activeID: UUID?
    let isPaused: Bool
    @Binding var selectedID: UUID?
    @Binding var query: String
    var compact = false

    var body: some View {
        let days = MeetingLibrary.days(records, matching: query)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.secondary)
                TextField(mText("Sök möten", "Search meetings"), text: $query)
                    .textFieldStyle(.plain).mumlaFont(size: 13)
                    .accessibilityLabel(mText("Sök möten", "Search meetings"))
                    .accessibilityIdentifier("meeting.library.search")
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                        .buttonStyle(.plain).help(mText("Rensa sökning", "Clear search"))
                        .accessibilityLabel(mText("Rensa sökning", "Clear search"))
                }
            }.frame(height: 24).padding(12).mumlaRecess(radius: 8)

            if days.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: records.isEmpty ? "text.book.closed" : "magnifyingglass")
                        .font(.system(size: 24)).foregroundStyle(palette.secondary)
                    Text(records.isEmpty ? mText("Inga sparade möten", "No saved meetings") : mText("Inga matchande möten", "No matching meetings"))
                        .mumlaFont(size: 16, weight: .medium)
                    if !query.isEmpty {
                        Button(mText("Rensa sökning", "Clear search")) { query = "" }
                            .buttonStyle(.plain).foregroundStyle(palette.accent)
                    }
                }.padding(.vertical, 24).frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(days) { day in
                            Section {
                                ForEach(day.meetings) { meeting in
                                    MeetingLibraryRow(meeting: meeting, preview: MeetingLibrary.preview(meeting, matching: query),
                                        active: activeID == meeting.id, paused: isPaused, selected: selectedID == meeting.id, compact: compact) {
                                            selectedID = meeting.id
                                        }
                                }
                            } header: {
                                Text(dayTitle(day.id)).mumlaFont(size: 12, weight: .medium)
                                    .foregroundStyle(palette.secondary).padding(.top, 12).padding(.bottom, 6)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }.padding(2)
                }.accessibilityIdentifier("meeting.library.list")
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return mText("Idag", "Today") }
        if Calendar.current.isDateInYesterday(date) { return mText("Igår", "Yesterday") }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct MeetingLibraryRow: View {
    @MumlaTheme private var palette
    let meeting: MeetingRecord
    let preview: String
    let active: Bool
    let paused: Bool
    let selected: Bool
    let compact: Bool
    let open: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(meeting.title).mumlaFont(size: 14, weight: .medium)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if !compact { Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(palette.secondary) }
                }
                HStack(spacing: 8) {
                    Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                    Text(MeetingRecord.timestamp(meeting.duration)).monospacedDigit()
                    Spacer(minLength: 0)
                    if active { Label(paused ? "PAUSE" : "REC", systemImage: paused ? "pause.fill" : "record.circle.fill").foregroundStyle(palette.recording) }
                    else { Text(state).lineLimit(1) }
                }.mumlaFont(size: 12).foregroundStyle(palette.secondary)
                if !preview.isEmpty {
                    Text(preview).mumlaFont(size: 12).foregroundStyle(palette.secondary)
                        .lineLimit(compact ? 1 : 2).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(12).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .contentShape(Rectangle())
                .background(selected ? palette.accent.opacity(0.13) : hovered ? palette.secondary.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).foregroundStyle(palette.ink)
            .onHover { hovered = $0 }
            .accessibilityIdentifier("meeting.library.open.\(meeting.id)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .help(meeting.title)
    }

    private var state: String {
        if meeting.capture == .interrupted { return mText("Avbrutet", "Interrupted") }
        if meeting.processing == .failed { return mText("Transkribering avbruten", "Transcription interrupted") }
        if meeting.processing == .ready { return mText("Transkript", "Transcript") }
        if meeting.processing == .processing || meeting.processing == .live { return mText("Transkriberar", "Transcribing") }
        return mText("Inspelning", "Recording")
    }
}
