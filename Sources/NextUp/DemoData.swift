import Foundation
import NextUpCore

enum DemoData {
    static func meetings(now: Date, bannerAnchor: Date? = nil) -> [Meeting] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        func at(_ base: Date, hour: Int, minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        func minutes(_ value: Double) -> Date { now.addingTimeInterval(value * 60) }

        let blue = RGB(r: 0.25, g: 0.5, b: 0.95)
        let green = RGB(r: 0.2, g: 0.7, b: 0.4)
        let orange = RGB(r: 0.95, g: 0.55, b: 0.2)
        let purple = RGB(r: 0.6, g: 0.4, b: 0.85)

        var result = [
            Meeting(id: "demo-1", title: "Sprint planning", start: minutes(-33), end: minutes(12), color: blue, joinURL: URL(string: "https://meet.google.com/abc-defg-hij")),
            Meeting(id: "demo-2", title: "Design review", start: minutes(30), end: minutes(75), color: purple, joinURL: URL(string: "https://zoom.us/j/123456789")),
            Meeting(id: "demo-3", title: "1:1 with Sam", start: minutes(135), end: minutes(165), color: green),
            Meeting(id: "demo-5", title: "Weekly sync", start: at(tomorrow, hour: 9, minute: 30), end: at(tomorrow, hour: 10, minute: 15), color: blue, joinURL: URL(string: "https://zoom.us/j/987654321")),
            Meeting(id: "demo-6", title: "Team retro", start: at(tomorrow, hour: 14), end: at(tomorrow, hour: 15), color: green),
        ]
        if let anchor = bannerAnchor {
            result.removeAll { $0.id == "demo-2" }
            let start = anchor.addingTimeInterval(65)
            result.append(Meeting(id: "demo-banner", title: "Design review", start: start, end: start.addingTimeInterval(45 * 60), color: purple, joinURL: URL(string: "https://zoom.us/j/123456789")))
        }
        return result
    }
}
