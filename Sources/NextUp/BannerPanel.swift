import AppKit
import SwiftUI

private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class BannerPanel: NSPanel {
    static let width: CGFloat = 620
    private static let topInset: CGFloat = 12
    private static let slide: CGFloat = 12

    private var hosting: NSHostingView<AnyView>?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
    }

    func setContent(_ view: some View) {
        let root = AnyView(view)
        if let hosting {
            hosting.rootView = root
        } else {
            let hosting = FirstClickHostingView(rootView: root)
            self.hosting = hosting
            contentView = hosting
        }
    }

    func present() {
        guard let hosting else { return }
        hosting.layoutSubtreeIfNeeded()
        let size = NSSize(width: Self.width, height: hosting.fittingSize.height)
        let visible = Self.targetScreen()?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = visible.midX - size.width / 2
        let y = visible.maxY - Self.topInset - size.height
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let target = NSRect(x: x, y: y, width: size.width, height: size.height)
        if isVisible {
            setFrame(target, display: true)
            animator().alphaValue = 1
            return
        }
        setFrame(reduceMotion ? target : target.offsetBy(dx: 0, dy: Self.slide), display: true)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            animator().alphaValue = 1
            if !reduceMotion { animator().setFrame(target, display: true) }
        }
    }

    func dismiss() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.alphaValue == 0 else { return }
                self.orderOut(nil)
            }
        })
    }

    private static func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
    }
}
