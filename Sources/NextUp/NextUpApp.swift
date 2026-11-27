import SwiftUI
import NextUpCore

@main
struct NextUpApp: App {
    @StateObject private var store: CalendarStore
    private let banner: BannerController

    init() {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--render-screenshots") {
            let directory = args.indices.contains(flag + 1) ? args[flag + 1] : "docs"
            MainActor.assumeIsolated { ScreenshotRenderer.run(into: directory) }
            exit(0)
        }
        let demoBanner = args.contains("--demo-banner")
        let demo = args.contains("--demo") || demoBanner
        let anchor: Date? = demoBanner ? Date() : nil
        let store = CalendarStore(demoProvider: demo ? { DemoData.meetings(now: $0, bannerAnchor: anchor) } : nil)
        _store = StateObject(wrappedValue: store)
        banner = MainActor.assumeIsolated { BannerController(store: store) }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            let text = store.access == .granted ? MeetingSelection.menuBarLabel(store.meetings, now: store.now) : ""
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                if !text.isEmpty { Text(text) }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
