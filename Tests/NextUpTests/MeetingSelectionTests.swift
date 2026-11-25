import XCTest
@testable import NextUpCore

final class MeetingSelectionTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func meeting(_ id: String, _ day: Int, _ h: Int, _ m: Int = 0, mins: Int = 30) -> Meeting {
        let s = date(day, h, m)
        return Meeting(id: id, title: "Meeting \(id)", start: s, end: s.addingTimeInterval(Double(mins) * 60))
    }

    func testAllRemainingTodayKeptEvenWhenMoreThanFour() {
        let now = date(25, 9)
        let ms = (0..<6).map { meeting("t\($0)", 25, 10 + $0) } + [meeting("tomorrow", 26, 9)]
        let result = MeetingSelection.visibleMeetings(ms, now: now, calendar: cal)
        XCTAssertEqual(result.map(\.id), ["t0", "t1", "t2", "t3", "t4", "t5"])
    }

    func testTopUpWithFollowingDaysToFour() {
        let now = date(25, 9)
        let ms = [meeting("a", 25, 10), meeting("d2", 27, 9), meeting("b", 26, 9), meeting("c", 26, 11), meeting("e", 28, 9)]
        let result = MeetingSelection.visibleMeetings(ms, now: now, calendar: cal)
        XCTAssertEqual(result.map(\.id), ["a", "b", "c", "d2"])
    }

    func testPastMeetingsDroppedAndInProgressKept() {
        let now = date(25, 10, 15)
        let ms = [meeting("past", 25, 9), meeting("live", 25, 10), meeting("next", 25, 11)]
        let result = MeetingSelection.visibleMeetings(ms, now: now, calendar: cal)
        XCTAssertEqual(result.map(\.id), ["live", "next"])
    }

    func testNothingTodayShowsUpcomingDays() {
        let now = date(25, 20)
        let ms = [meeting("a", 26, 9), meeting("b", 27, 9)]
        XCTAssertEqual(MeetingSelection.visibleMeetings(ms, now: now, calendar: cal).map(\.id), ["a", "b"])
    }

    func testDayHeaders() {
        let now = date(25, 9)
        XCTAssertEqual(MeetingSelection.dayHeader(for: date(25, 15), now: now, calendar: cal), "Today")
        XCTAssertEqual(MeetingSelection.dayHeader(for: date(26, 15), now: now, calendar: cal), "Tomorrow")
        XCTAssertEqual(MeetingSelection.dayHeader(for: date(30, 15), now: now, calendar: cal), "Monday")
    }

    func testGrouping() {
        let now = date(25, 9)
        let ms = [meeting("a", 25, 10), meeting("b", 26, 9), meeting("c", 26, 10), meeting("d", 27, 9)]
        let groups = MeetingSelection.grouped(ms, now: now, calendar: cal)
        XCTAssertEqual(groups.map(\.header), ["Today", "Tomorrow", "Friday"])
        XCTAssertEqual(groups[1].meetings.count, 2)
    }

    func testLabelInProgress() {
        let now = date(25, 10, 18)
        let ms = [meeting("a", 25, 10, 0, mins: 30)]
        XCTAssertEqual(MeetingSelection.menuBarLabel(ms, now: now, calendar: cal), "Meeting a · 12 min left")
    }

    func testLabelUpcomingFormats() {
        let now = date(25, 9)
        XCTAssertEqual(MeetingSelection.menuBarLabel([meeting("a", 25, 9, 30)], now: now, calendar: cal), "Meeting a · in 30 min")
        XCTAssertEqual(MeetingSelection.menuBarLabel([meeting("a", 25, 10, 20)], now: now, calendar: cal), "Meeting a · in 1h 20m")
        XCTAssertEqual(MeetingSelection.menuBarLabel([meeting("a", 25, 9, 0)], now: now.addingTimeInterval(-30), calendar: cal), "Meeting a · now")
    }

    func testLabelEmptyWhenNothingLeftToday() {
        let now = date(25, 20)
        XCTAssertEqual(MeetingSelection.menuBarLabel([meeting("a", 26, 9)], now: now, calendar: cal), "")
        XCTAssertEqual(MeetingSelection.menuBarLabel([], now: now, calendar: cal), "")
    }

    func testUpcomingWithinTenMinutesBeatsInProgress() {
        let now = date(25, 10, 20)
        let ms = [meeting("live", 25, 10, 0, mins: 60), meeting("soon", 25, 10, 25)]
        XCTAssertEqual(MeetingSelection.menuBarLabel(ms, now: now, calendar: cal), "Meeting soon · in 5 min")
    }

    func testInProgressWinsWhenUpcomingIsFar() {
        let now = date(25, 10, 20)
        let ms = [meeting("live", 25, 10, 0, mins: 60), meeting("later", 25, 10, 45)]
        XCTAssertEqual(MeetingSelection.menuBarLabel(ms, now: now, calendar: cal), "Meeting live · 40 min left")
    }

    func testTruncation() {
        XCTAssertEqual(MeetingSelection.truncate("Short"), "Short")
        let long = MeetingSelection.truncate("Quarterly planning and roadmap review")
        XCTAssertTrue(long.hasSuffix("…"))
        XCTAssertLessThanOrEqual(long.count, 22)
    }

    func testJoinURLExtraction() {
        XCTAssertEqual(MeetingSelection.joinURL(in: [nil, "Room 4", "Join: https://meet.google.com/abc-defg-hij."])?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(MeetingSelection.joinURL(in: ["https://us02web.zoom.us/j/123?pwd=x"])?.host, "us02web.zoom.us")
        XCTAssertEqual(MeetingSelection.joinURL(in: ["<https://teams.microsoft.com/l/meetup-join/abc>"])?.host, "teams.microsoft.com")
    }

    func testJoinURLIgnoresOtherLinksAndPrefersFieldOrder() {
        XCTAssertNil(MeetingSelection.joinURL(in: ["https://example.com/doc", "https://notzoom.us.evil.com/x"]))
        let url = MeetingSelection.joinURL(in: ["https://zoom.us/j/1", "https://meet.google.com/aaa"])
        XCTAssertEqual(url?.host, "zoom.us")
        XCTAssertEqual(MeetingSelection.joinURL(in: ["see https://example.com then https://meet.google.com/zzz"])?.host, "meet.google.com")
    }
}
