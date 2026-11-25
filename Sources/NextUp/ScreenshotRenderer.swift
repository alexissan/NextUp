import AppKit
import SwiftUI
import NextUpCore

private final class ActiveWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    override var canBecomeKey: Bool { true }
}

@MainActor
enum ScreenshotRenderer {
    static func run(into directory: String) {
        let dir = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let store = CalendarStore(demoProvider: DemoData.meetings(now:))
        let suite = "dev.alexissantos.nextup.screenshots"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let shots: [(String, NSAppearance.Name, Theme)] = [
            ("popover-light", .aqua, .classic),
            ("popover-dark", .darkAqua, .classic),
            ("popover-retro", .darkAqua, .retro),
        ]
        for (name, appearance, theme) in shots {
            let dark = appearance == .darkAqua
            defaults.set(theme.rawValue, forKey: Theme.storageKey)
            let view = PopoverView(store: store, defaults: defaults)
                .background(Color(nsColor: dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.96, alpha: 1)))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                .padding(20)
                .environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.controlActiveState, .key)
            write(view, appearance: appearance, to: dir.appendingPathComponent("\(name).png"))
        }

        let now = Date()
        let label = MeetingSelection.menuBarLabel([
            Meeting(id: "strip", title: "Design review", start: now.addingTimeInterval(30 * 60 + 30), end: now.addingTimeInterval(75 * 60))
        ], now: now)
        let strip = HStack(spacing: 4) {
            Image(systemName: "calendar")
            Text(label)
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.black.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(nsColor: NSColor(white: 0.86, alpha: 1)))
        write(strip, appearance: .aqua, to: dir.appendingPathComponent("menubar.png"))
    }

    private static func write<V: View>(_ view: V, appearance: NSAppearance.Name, to url: URL) {
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = ActiveWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        hosting.layoutSubtreeIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }
}
