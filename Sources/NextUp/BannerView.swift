import SwiftUI
import NextUpCore

struct BannerView: View {
    let meetings: [Meeting]
    let now: Date
    let theme: Theme
    let onJoin: (Meeting) -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private static let maxRows = 3
    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Starting soon")
                    .font(.caption.weight(.semibold))
                    .tracking(palette.headerTracking)
                    .foregroundStyle(palette.header)
                    .shadow(color: palette.isRetro ? Neon.cyan.opacity(0.6) : .clear, radius: 4)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss"))
            }
            ForEach(meetings.prefix(Self.maxRows)) { meeting in
                row(meeting)
            }
            if meetings.count > Self.maxRows {
                Text("+\(meetings.count - Self.maxRows) more")
                    .font(.callout)
                    .foregroundStyle(palette.secondary)
            }
        }
        .padding(20)
        .frame(width: 620)
        .background { background(shape) }
        .clipShape(shape)
        .overlay { border(shape) }
        .shadow(color: palette.isRetro ? Neon.magenta.opacity(0.45) : .clear, radius: 14)
        .environment(\.palette, palette)
        .environment(\.colorScheme, palette.isRetro ? .dark : systemScheme)
        .tint(palette.tint)
    }

    private func row(_ meeting: Meeting) -> some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(meeting.color.color)
                    .frame(width: 12, height: 12)
                    .shadow(color: palette.isRetro ? meeting.color.color : .clear, radius: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.title)
                        .font(palette.bannerTitleFont)
                        .fontWidth(palette.titleWidth)
                        .lineLimit(2)
                    Text(timeRange(meeting))
                        .font(.callout)
                        .foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 8)
                Text(BannerSchedule.countdown(for: meeting, now: now))
                    .font(palette.bannerCountdownFont)
                    .monospacedDigit()
                    .foregroundStyle(palette.countdownStyle)
                    .shadow(color: palette.isRetro ? Neon.magenta.opacity(0.7) : .clear, radius: 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(meeting.title), \(BannerSchedule.spokenCountdown(for: meeting, now: now))"))
            if meeting.joinURL != nil {
                Button {
                    onJoin(meeting)
                } label: {
                    Label("Join", systemImage: "video.fill").padding(.horizontal, 10)
                }
                .buttonStyle(JoinButtonStyle())
                .accessibilityLabel(Text("Join \(meeting.title)"))
            }
        }
    }

    @ViewBuilder
    private func background(_ shape: RoundedRectangle) -> some View {
        if palette.isRetro {
            SynthwaveBackdrop()
        } else if contrast == .increased {
            Color(nsColor: .windowBackgroundColor)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private func border(_ shape: RoundedRectangle) -> some View {
        if palette.isRetro {
            shape.strokeBorder(
                LinearGradient(colors: [Neon.magenta, Neon.violet, Neon.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.5
            )
        } else if contrast == .increased {
            shape.strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.5)
        } else {
            shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

struct LiveBannerView: View {
    @AppStorage private var theme: Theme
    let meetings: [Meeting]
    let onJoin: (Meeting) -> Void
    let onDismiss: () -> Void

    init(meetings: [Meeting], defaults: UserDefaults = .standard, onJoin: @escaping (Meeting) -> Void, onDismiss: @escaping () -> Void) {
        self.meetings = meetings
        self.onJoin = onJoin
        self.onDismiss = onDismiss
        _theme = AppStorage(wrappedValue: .classic, Theme.storageKey, store: defaults)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            BannerView(meetings: meetings, now: context.date, theme: theme, onJoin: onJoin, onDismiss: onDismiss)
        }
    }
}
