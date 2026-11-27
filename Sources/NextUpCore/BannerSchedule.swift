import Foundation

public enum BannerSchedule {
    public static let storageKey = "bannerEnabled"
    public static let leadTime: TimeInterval = 60
    public static let lateGrace: TimeInterval = 120
    public static let lingerAfterStart: TimeInterval = 60
    public static let minimumVisible: TimeInterval = 30

    public static func due(_ meetings: [Meeting], now: Date, shown: Set<String>) -> [Meeting] {
        meetings
            .filter { !shown.contains($0.id) && $0.start.addingTimeInterval(-leadTime) <= now && now < $0.start.addingTimeInterval(lateGrace) }
            .sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    public static func nextFireDate(_ meetings: [Meeting], now: Date, shown: Set<String>) -> Date? {
        meetings
            .filter { !shown.contains($0.id) }
            .map { $0.start.addingTimeInterval(-leadTime) }
            .filter { $0 > now }
            .min()
    }

    public static func dismissDate(for meetings: [Meeting], now: Date) -> Date? {
        guard let latest = meetings.map(\.start).max() else { return nil }
        return max(latest.addingTimeInterval(lingerAfterStart), now.addingTimeInterval(minimumVisible))
    }

    public static func pruned(_ shown: [String: Date], now: Date) -> [String: Date] {
        shown.filter { $0.value.addingTimeInterval(lateGrace) > now }
    }

    public static func countdown(for meeting: Meeting, now: Date) -> String {
        let s = secondsUntilStart(meeting, now: now)
        if s <= 0 { return "now" }
        if s >= 60 { return "in \(s / 60) min" }
        return "in \(s) s"
    }

    public static func spokenCountdown(for meeting: Meeting, now: Date) -> String {
        let s = secondsUntilStart(meeting, now: now)
        if s <= 0 { return "starting now" }
        if s >= 60 {
            let m = s / 60
            return m == 1 ? "starts in 1 minute" : "starts in \(m) minutes"
        }
        return s == 1 ? "starts in 1 second" : "starts in \(s) seconds"
    }

    private static func secondsUntilStart(_ meeting: Meeting, now: Date) -> Int {
        Int(meeting.start.timeIntervalSince(now).rounded(.up))
    }
}
