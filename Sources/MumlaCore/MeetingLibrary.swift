import Foundation

/// Local, read-only presentation of complete meeting records.
public enum MeetingLibrary {
    public struct Day: Identifiable, Equatable, Sendable {
        public var id: Date
        public var meetings: [MeetingRecord]
    }

    public static func days(_ records: [MeetingRecord], matching query: String,
                            calendar: Calendar = .current) -> [Day] {
        let terms = searchTerms(query)
        let matches = records.filter { record in
            guard !terms.isEmpty else { return true }
            let searchable = normalized(([record.title, record.sourceName]
                + Array(record.speakerNames.values)
                + Array(Set(record.segments.map { record.speakerName($0.speaker) }))
                + record.segments.map(\.text)).joined(separator: " "))
            return terms.allSatisfy { searchable.contains($0) }
        }.sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt
        }
        var days: [Day] = []
        for record in matches {
            let date = calendar.startOfDay(for: record.createdAt)
            if days.last?.id == date { days[days.count - 1].meetings.append(record) }
            else { days.append(Day(id: date, meetings: [record])) }
        }
        return days
    }

    public static func preview(_ record: MeetingRecord, matching query: String) -> String {
        let terms = searchTerms(query)
        let segments = record.orderedSegments
        let match = terms.isEmpty ? nil : segments.first { segment in
            let text = normalized(segment.text)
            return terms.contains { text.contains($0) }
        }
        let text = (match ?? segments.first)?.text ?? ""
        return String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(180))
    }

    private static func searchTerms(_ text: String) -> [String] {
        normalized(text).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
