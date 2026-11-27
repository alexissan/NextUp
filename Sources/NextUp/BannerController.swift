import AppKit
import Combine
import NextUpCore

@MainActor
final class BannerController {
    private let store: CalendarStore
    private let defaults: UserDefaults
    private var shown: [String: Date] = [:]
    private var visible: [Meeting] = []
    private var fireTimer: Timer?
    private var dismissTimer: Timer?
    private var panel: BannerPanel?
    private var lastEnabled: Bool
    private var cancellables: Set<AnyCancellable> = []

    init(store: CalendarStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        lastEnabled = defaults.object(forKey: BannerSchedule.storageKey) as? Bool ?? true
        store.$meetings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.settingsChanged() }
            }
            .store(in: &cancellables)
    }

    private var enabled: Bool {
        defaults.object(forKey: BannerSchedule.storageKey) as? Bool ?? true
    }

    private func settingsChanged() {
        let current = enabled
        guard current != lastEnabled else { return }
        lastEnabled = current
        evaluate()
    }

    private func evaluate() {
        let now = Date()
        shown = BannerSchedule.pruned(shown, now: now)
        guard enabled else {
            closeBanner()
            fireTimer?.invalidate()
            fireTimer = nil
            return
        }
        let meetings = store.meetings
        let due = BannerSchedule.due(meetings, now: now, shown: Set(shown.keys))
        if !due.isEmpty {
            for meeting in due {
                shown[meeting.id] = meeting.start
                visible.append(meeting)
            }
            showBanner()
            let spoken = due.map { "\($0.title), \(BannerSchedule.spokenCountdown(for: $0, now: now))" }.joined(separator: ". ")
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [.announcement: spoken, .priority: NSAccessibilityPriorityLevel.high.rawValue]
            )
            scheduleDismiss(now: now)
        }
        scheduleFire(meetings: meetings, now: now)
    }

    private func scheduleFire(meetings: [Meeting], now: Date) {
        fireTimer?.invalidate()
        fireTimer = nil
        guard let date = BannerSchedule.nextFireDate(meetings, now: now, shown: Set(shown.keys)) else { return }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        fireTimer = timer
    }

    private func scheduleDismiss(now: Date) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let date = BannerSchedule.dismissDate(for: visible, now: now) else { return }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeBanner() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        dismissTimer = timer
    }

    private func showBanner() {
        let panel = self.panel ?? BannerPanel()
        self.panel = panel
        panel.setContent(
            LiveBannerView(
                meetings: visible,
                defaults: defaults,
                onJoin: { [weak self] meeting in self?.join(meeting) },
                onDismiss: { [weak self] in self?.closeBanner() }
            )
        )
        panel.present()
    }

    private func join(_ meeting: Meeting) {
        if let url = meeting.joinURL { NSWorkspace.shared.open(url) }
        closeBanner()
    }

    private func closeBanner() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard !visible.isEmpty else { return }
        visible = []
        panel?.dismiss()
    }
}
