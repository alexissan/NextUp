import AppKit
import EventKit
import NextUpCore

@MainActor
final class CalendarStore: ObservableObject {
    enum Access {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var now = Date()
    @Published private(set) var access: Access = .unknown

    private lazy var store = EKEventStore()
    private let demoProvider: ((Date) -> [Meeting])?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(demoProvider: ((Date) -> [Meeting])? = nil) {
        self.demoProvider = demoProvider
        if let demoProvider {
            access = .granted
            meetings = demoProvider(now)
            let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            return
        }
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        requestAccess()
    }

    func requestAccess() {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            access = .granted
            refresh()
            return
        }
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            access = granted ? .granted : .denied
            refresh()
        }
    }

    func refresh() {
        now = Date()
        if let demoProvider {
            meetings = demoProvider(now)
            return
        }
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            access = .granted
        } else if access == .granted {
            access = .denied
        }
        guard access == .granted else {
            meetings = []
            return
        }
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        meetings = store.events(matching: predicate).compactMap(Self.meeting(from:))
    }

    private static func meeting(from event: EKEvent) -> Meeting? {
        if event.isAllDay || event.status == .canceled { return nil }
        if event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) == true { return nil }
        let link = MeetingSelection.joinURL(in: [event.url?.absoluteString, event.location, event.notes])
        let color = event.calendar.color?.usingColorSpace(.sRGB)
        let rgb = color.map { RGB(r: Double($0.redComponent), g: Double($0.greenComponent), b: Double($0.blueComponent)) } ?? RGB(r: 0.3, g: 0.5, b: 1)
        let id = (event.eventIdentifier ?? UUID().uuidString) + "@\(event.startDate.timeIntervalSince1970)"
        return Meeting(id: id, title: event.title ?? "Untitled", start: event.startDate, end: event.endDate, color: rgb, joinURL: link)
    }
}
