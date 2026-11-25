import Foundation

public struct RGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct Meeting: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var color: RGB
    public var joinURL: URL?

    public init(id: String, title: String, start: Date, end: Date, color: RGB = RGB(r: 0.3, g: 0.5, b: 1), joinURL: URL? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.color = color
        self.joinURL = joinURL
    }

    public func isInProgress(at now: Date) -> Bool {
        start <= now && now < end
    }
}

public struct DayGroup: Equatable, Sendable {
    public var header: String
    public var meetings: [Meeting]
}

public enum MeetingSelection {
    public static let minimumCount = 4

    public static func visibleMeetings(_ meetings: [Meeting], now: Date, calendar: Calendar = .current, minimum: Int = minimumCount) -> [Meeting] {
        let sorted = meetings.filter { $0.end > now }.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
        guard let tomorrow = nextDayStart(after: now, calendar: calendar) else { return sorted }
        let today = sorted.filter { $0.start < tomorrow }
        guard today.count < minimum else { return today }
        let later = sorted.filter { $0.start >= tomorrow }
        return today + later.prefix(minimum - today.count)
    }

    public static func focusMeeting(_ meetings: [Meeting], now: Date) -> Meeting? {
        let remaining = meetings.filter { $0.end > now }.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
        let current = remaining.first { $0.isInProgress(at: now) }
        let upcoming = remaining.first { $0.start > now }
        if let upcoming, upcoming.start.timeIntervalSince(now) <= 600 { return upcoming }
        return current ?? upcoming
    }

    public static func menuBarLabel(_ meetings: [Meeting], now: Date, calendar: Calendar = .current) -> String {
        guard let tomorrow = nextDayStart(after: now, calendar: calendar) else { return "" }
        let todays = meetings.filter { $0.start < tomorrow }
        guard let meeting = focusMeeting(todays, now: now) else { return "" }
        return "\(truncate(meeting.title)) · \(countdown(for: meeting, now: now))"
    }

    public static func countdown(for meeting: Meeting, now: Date) -> String {
        if meeting.isInProgress(at: now) {
            let minutes = max(1, Int((meeting.end.timeIntervalSince(now) / 60).rounded(.up)))
            return "\(duration(minutes: minutes)) left"
        }
        let minutes = Int(meeting.start.timeIntervalSince(now) / 60)
        if minutes < 1 { return "now" }
        return "in \(duration(minutes: minutes))"
    }

    public static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    public static func progress(for meeting: Meeting, now: Date) -> Double? {
        guard meeting.isInProgress(at: now) else { return nil }
        let total = meeting.end.timeIntervalSince(meeting.start)
        guard total > 0 else { return nil }
        return min(1, max(0, now.timeIntervalSince(meeting.start) / total))
    }

    public static func truncate(_ title: String, limit: Int = 22) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    public static func dayHeader(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        let day = max(calendar.startOfDay(for: date), calendar.startOfDay(for: now))
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: day).day ?? 0
        if diff <= 0 { return "Today" }
        if diff == 1 { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    public static func grouped(_ meetings: [Meeting], now: Date, calendar: Calendar = .current) -> [DayGroup] {
        var groups: [DayGroup] = []
        for meeting in meetings {
            let header = dayHeader(for: meeting.start, now: now, calendar: calendar)
            if let last = groups.last, last.header == header {
                groups[groups.count - 1].meetings.append(meeting)
            } else {
                groups.append(DayGroup(header: header, meetings: [meeting]))
            }
        }
        return groups
    }

    public static func joinURL(in fields: [String?]) -> URL? {
        let pattern = #"https?://[^\s<>"'\)\]]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        for field in fields {
            guard let field, !field.isEmpty else { continue }
            let range = NSRange(field.startIndex..., in: field)
            for match in regex.matches(in: field, range: range) {
                guard let r = Range(match.range, in: field) else { continue }
                var text = String(field[r])
                while let last = text.last, ".,;:!?".contains(last) { text.removeLast() }
                if let url = URL(string: text), isVideoHost(url.host) { return url }
            }
        }
        return nil
    }

    static func isVideoHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        let suffixes = ["meet.google.com", "zoom.us", "zoom.com", "teams.microsoft.com", "teams.live.com"]
        return suffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func nextDayStart(after date: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
    }
}
