import XCTest
@testable import NextUpCore

final class ThemeTests: XCTestCase {
    func testStoredValuesAreStable() {
        XCTAssertEqual(Theme.classic.rawValue, "classic")
        XCTAssertEqual(Theme.retro.rawValue, "retro")
        XCTAssertEqual(Theme.storageKey, "theme")
    }

    func testSelectorOrderPutsClassicFirst() {
        XCTAssertEqual(Theme.allCases, [.classic, .retro])
    }

    func testRestoresAStoredTheme() {
        XCTAssertEqual(Theme(storedValue: "retro"), .retro)
        XCTAssertEqual(Theme(storedValue: "classic"), .classic)
    }

    func testFallsBackToClassicForMissingOrUnknownValues() {
        XCTAssertEqual(Theme(storedValue: nil), .classic)
        XCTAssertEqual(Theme(storedValue: ""), .classic)
        XCTAssertEqual(Theme(storedValue: "vaporwave"), .classic)
    }
}
