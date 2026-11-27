import XCTest
@testable import NextUpCore

final class BannerScheduleTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    func date(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: hour, minute: minute, second: second))!
    }

    func meeting(_ id: String, _ h: Int, _ m: Int = 0, _ s: Int = 0) -> Meeting {
        let start = date(h, m, s)
        return Meeting(id: id, title: "Meeting \(id)", start: start, end: start.addingTimeInterval(1800))
    }

    func ids(_ meetings: [Meeting]) -> [String] { meetings.map(\.id) }

    func testDueWindowEdges() {
        let m = meeting("a", 10)
        let start = m.start
        func due(_ offset: TimeInterval) -> Bool {
            !BannerSchedule.due([m], now: start.addingTimeInterval(offset), shown: []).isEmpty
        }
        XCTAssertFalse(due(-61))
        XCTAssertTrue(due(-60))
        XCTAssertTrue(due(-1))
        XCTAssertTrue(due(0))
        XCTAssertTrue(due(119))
        XCTAssertFalse(due(120))
    }

    func testShownIdsExcluded() {
        let ms = [meeting("a", 10), meeting("b", 10)]
        let result = BannerSchedule.due(ms, now: date(10), shown: ["a"])
        XCTAssertEqual(ids(result), ["b"])
    }

    func testSimultaneousMeetingsOrderedById() {
        let ms = [meeting("b", 10), meeting("a", 10)]
        XCTAssertEqual(ids(BannerSchedule.due(ms, now: date(9, 59, 30), shown: [])), ["a", "b"])
    }

    func testDifferentStartsOrderedByStart() {
        let ms = [meeting("a", 10, 0, 30), meeting("b", 10, 0, 0)]
        XCTAssertEqual(ids(BannerSchedule.due(ms, now: date(9, 59, 45), shown: [])), ["b", "a"])
    }

    func testMovedEventWithNewIdIsDueAgain() {
        let moved = meeting("event@10:30", 10, 30)
        let result = BannerSchedule.due([moved], now: date(10, 29, 30), shown: ["event@10:00"])
        XCTAssertEqual(ids(result), ["event@10:30"])
    }

    func testNextFireDatePicksEarliestFuture() {
        let ms = [meeting("late", 11), meeting("early", 10)]
        XCTAssertEqual(BannerSchedule.nextFireDate(ms, now: date(9), shown: []), date(9, 59))
    }

    func testNextFireDateSkipsShown() {
        let ms = [meeting("late", 11), meeting("early", 10)]
        XCTAssertEqual(BannerSchedule.nextFireDate(ms, now: date(9), shown: ["early"]), date(10, 59))
    }

    func testNextFireDateNilWhenNoMeetings() {
        XCTAssertNil(BannerSchedule.nextFireDate([], now: date(9), shown: []))
    }

    func testNextFireDateNilWhenInsideWindow() {
        XCTAssertNil(BannerSchedule.nextFireDate([meeting("a", 10)], now: date(9, 59, 30), shown: []))
    }

    func testNextFireDateNilWhenExactlyAtFireDate() {
        XCTAssertNil(BannerSchedule.nextFireDate([meeting("a", 10)], now: date(9, 59), shown: []))
    }

    func testDismissDateIsLatestStartPlusLinger() {
        let ms = [meeting("a", 10), meeting("b", 10, 0, 30)]
        XCTAssertEqual(BannerSchedule.dismissDate(for: ms, now: date(9, 59, 30)), date(10, 1, 30))
    }

    func testDismissDateLateWakeKeepsBannerForMinimumVisible() {
        let now = date(10, 1, 30)
        XCTAssertEqual(BannerSchedule.dismissDate(for: [meeting("a", 10)], now: now), now.addingTimeInterval(30))
    }

    func testDismissDateBeforeStartUsesLinger() {
        XCTAssertEqual(BannerSchedule.dismissDate(for: [meeting("a", 10)], now: date(9, 59, 10)), date(10, 1))
    }

    func testDismissDateNilForEmpty() {
        XCTAssertNil(BannerSchedule.dismissDate(for: [], now: date(10)))
    }

    func testPrunedKeepsRecentAndDropsOld() {
        let now = date(10, 5)
        let shown = [
            "future": date(10, 10),
            "recent": now.addingTimeInterval(-119),
            "edge": now.addingTimeInterval(-120),
            "old": now.addingTimeInterval(-600)
        ]
        let result = BannerSchedule.pruned(shown, now: now)
        XCTAssertEqual(Set(result.keys), ["future", "recent"])
    }

    func testCountdownStrings() {
        let m = meeting("a", 10)
        func text(_ secondsBefore: TimeInterval) -> String {
            BannerSchedule.countdown(for: m, now: m.start.addingTimeInterval(-secondsBefore))
        }
        XCTAssertEqual(text(90), "in 1 min")
        XCTAssertEqual(text(150), "in 2 min")
        XCTAssertEqual(text(60), "in 1 min")
        XCTAssertEqual(text(45), "in 45 s")
        XCTAssertEqual(text(0.4), "in 1 s")
        XCTAssertEqual(text(0), "now")
        XCTAssertEqual(text(-30), "now")
    }

    func testSpokenCountdownStrings() {
        let m = meeting("a", 10)
        func text(_ secondsBefore: TimeInterval) -> String {
            BannerSchedule.spokenCountdown(for: m, now: m.start.addingTimeInterval(-secondsBefore))
        }
        XCTAssertEqual(text(90), "starts in 1 minute")
        XCTAssertEqual(text(150), "starts in 2 minutes")
        XCTAssertEqual(text(60), "starts in 1 minute")
        XCTAssertEqual(text(45), "starts in 45 seconds")
        XCTAssertEqual(text(0.4), "starts in 1 second")
        XCTAssertEqual(text(0), "starting now")
        XCTAssertEqual(text(-30), "starting now")
    }
}
