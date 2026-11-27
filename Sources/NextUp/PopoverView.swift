import SwiftUI
import ServiceManagement
import NextUpCore

extension RGB {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

let timeFormat: Date.FormatStyle = .dateTime.hour().minute()

func timeRange(_ m: Meeting) -> String {
    "\(m.start.formatted(timeFormat)) – \(m.end.formatted(timeFormat))"
}

func open(_ url: URL) {
    NSWorkspace.shared.open(url)
}

private extension Theme {
    var title: LocalizedStringKey {
        switch self {
        case .classic: "Classic"
        case .retro: "Retro"
        }
    }
}

struct PopoverView: View {
    @ObservedObject var store: CalendarStore
    @AppStorage private var theme: Theme
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage private var bannerEnabled: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init(store: CalendarStore, defaults: UserDefaults = .standard) {
        self.store = store
        _theme = AppStorage(wrappedValue: .classic, Theme.storageKey, store: defaults)
        _bannerEnabled = AppStorage(wrappedValue: true, BannerSchedule.storageKey, store: defaults)
    }

    private var palette: Palette { Palette(theme: theme) }

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
            Divider().overlay(palette.isRetro ? Neon.magenta.opacity(0.5) : .clear)
            modePicker
            footer
        }
        .padding(14)
        .frame(width: 340)
        .background {
            if palette.isRetro {
                SynthwaveBackdrop().transition(.opacity)
            }
        }
        .environment(\.palette, palette)
        .environment(\.colorScheme, palette.isRetro ? .dark : systemScheme)
        .tint(palette.tint)
        .animation(.easeInOut(duration: 0.25), value: theme)
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
                        .foregroundStyle(palette.secondary)
                }
            }
        }
        ForEach(Array(MeetingSelection.grouped(rest, now: store.now).enumerated()), id: \.offset) { _, group in
            VStack(alignment: .leading, spacing: 4) {
                GroupHeader(text: group.header)
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

    private var modePicker: some View {
        Picker("Mode", selection: $theme) {
            ForEach(Theme.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .accessibilityLabel(Text("Mode"))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {}
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
                Toggle("Banner before meetings", isOn: $bannerEnabled)
            }
            .toggleStyle(.checkbox)
            .font(.caption)
            HStack(spacing: 10) {
                Spacer()
                Button("Open Calendar") {
                    open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(FooterLinkStyle())
            .font(.caption)
        }
    }
}

private struct GroupHeader: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(palette.headerTracking)
            .foregroundStyle(palette.header)
            .shadow(color: palette.isRetro ? Neon.cyan.opacity(0.6) : .clear, radius: 4)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct HeroCard: View {
    let meeting: Meeting
    let now: Date
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(meeting.color.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: palette.isRetro ? meeting.color.color : .clear, radius: 4)
                Text(timeRange(meeting)).font(.caption).foregroundStyle(palette.secondary)
            }
            Text(meeting.title)
                .font(.headline)
                .fontWidth(palette.titleWidth)
                .lineLimit(2)
            Text(MeetingSelection.countdown(for: meeting, now: now))
                .font(palette.countdownFont)
                .monospacedDigit()
                .foregroundStyle(palette.countdownStyle)
                .shadow(color: palette.isRetro ? Neon.magenta.opacity(0.7) : .clear, radius: 8)
            if let progress = MeetingSelection.progress(for: meeting, now: now) {
                ProgressBar(progress: progress, color: meeting.color.color)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Progress"))
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
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
        .modifier(CardBackground())
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    @State private var hovering = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(meeting.color.color)
                .frame(width: 3, height: 28)
                .shadow(color: palette.isRetro ? meeting.color.color : .clear, radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .font(.subheadline)
                    .fontWidth(palette.titleWidth)
                    .lineLimit(1)
                Text(timeRange(meeting)).font(.caption).foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 4)
            if meeting.joinURL != nil {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(palette.isRetro ? Neon.cyan : .secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(hovering && meeting.joinURL != nil ? palette.hoverFill : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if let url = meeting.joinURL { open(url) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(meeting.joinURL != nil ? .isButton : [])
        .accessibilityHint(meeting.joinURL != nil ? Text("Opens the video call") : Text(""))
    }
}

private struct ProgressBar: View {
    let progress: Double
    let color: Color
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule()
                    .fill(palette.progressFill(color))
                    .frame(width: proxy.size.width * progress)
                    .shadow(color: palette.isRetro ? Neon.magenta.opacity(0.8) : .clear, radius: 5)
            }
        }
        .frame(height: 5)
    }
}

private struct FooterLinkStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.link)
            .shadow(color: palette.isRetro ? Neon.cyan.opacity(0.5) : .clear, radius: 3)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

struct JoinButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .fontWidth(palette.titleWidth)
            .foregroundStyle(.white)
            .padding(.vertical, 7)
            .background(palette.joinFill(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: palette.isRetro ? Neon.magenta.opacity(0.6) : .clear, radius: 8)
    }
}
