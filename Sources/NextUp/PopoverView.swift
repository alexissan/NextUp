import SwiftUI
import ServiceManagement
import NextUpCore

private extension RGB {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

private let timeFormat: Date.FormatStyle = .dateTime.hour().minute()

private func timeRange(_ m: Meeting) -> String {
    "\(m.start.formatted(timeFormat)) – \(m.end.formatted(timeFormat))"
}

private func open(_ url: URL) {
    NSWorkspace.shared.open(url)
}

struct PopoverView: View {
    @ObservedObject var store: CalendarStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.access {
            case .granted:
                content
            case .denied:
                permissionView
            case .unknown:
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    @ViewBuilder
    private var content: some View {
        let visible = MeetingSelection.visibleMeetings(store.meetings, now: store.now)
        let hero = MeetingSelection.focusMeeting(visible, now: store.now)
        let rest = visible.filter { $0.id != hero?.id }
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: store.now)) ?? store.now
        let todayCount = visible.filter { $0.start < startOfTomorrow }.count

        if let hero {
            HeroCard(meeting: hero, now: store.now)
        }
        if todayCount == 0 {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing else today").font(.headline)
                if let next = visible.first {
                    Text("Next: \(MeetingSelection.dayHeader(for: next.start, now: store.now))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        ForEach(Array(MeetingSelection.grouped(rest, now: store.now).enumerated()), id: \.offset) { _, group in
            VStack(alignment: .leading, spacing: 4) {
                Text(group.header)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(group.meetings) { MeetingRow(meeting: $0) }
            }
        }
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NextUp needs calendar access to show your meetings.")
                .font(.subheadline)
            Button("Open Calendar Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    open(url)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    do {
                        if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {}
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)
            Spacer()
            Button("Open Calendar") {
                open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.link)
        .font(.caption)
    }
}

private struct HeroCard: View {
    let meeting: Meeting
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(meeting.color.color).frame(width: 8, height: 8)
                Text(timeRange(meeting)).font(.caption).foregroundStyle(.secondary)
            }
            Text(meeting.title).font(.headline).lineLimit(2)
            Text(MeetingSelection.countdown(for: meeting, now: now))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let progress = MeetingSelection.progress(for: meeting, now: now) {
                ProgressBar(progress: progress, color: meeting.color.color)
            }
            if let url = meeting.joinURL {
                Button {
                    open(url)
                } label: {
                    Label("Join", systemImage: "video.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(JoinButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(meeting.color.color).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title).font(.subheadline).lineLimit(1)
                Text(timeRange(meeting)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if meeting.joinURL != nil {
                Image(systemName: "video.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(hovering && meeting.joinURL != nil ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if let url = meeting.joinURL { open(url) }
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 5)
    }
}

private struct JoinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
