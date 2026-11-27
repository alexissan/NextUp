import SwiftUI
import NextUpCore

enum Neon {
    static let night = Color(red: 0.06, green: 0.02, blue: 0.14)
    static let dusk = Color(red: 0.20, green: 0.06, blue: 0.38)
    static let horizon = Color(red: 0.45, green: 0.08, blue: 0.45)
    static let magenta = Color(red: 1.0, green: 0.18, blue: 0.80)
    static let violet = Color(red: 0.62, green: 0.31, blue: 0.95)
    static let cyan = Color(red: 0.10, green: 0.92, blue: 1.0)
    static let lavender = Color(red: 0.84, green: 0.76, blue: 1.0)
    static let sunTop = Color(red: 1.0, green: 0.86, blue: 0.35)
}

struct Palette {
    let theme: Theme

    var isRetro: Bool { theme == .retro }

    var secondary: Color { isRetro ? Neon.lavender.opacity(0.78) : .secondary }
    var header: Color { isRetro ? Neon.cyan : .secondary }
    var headerTracking: CGFloat { isRetro ? 1.6 : 0 }
    var hoverFill: Color { isRetro ? Neon.magenta.opacity(0.16) : Color.primary.opacity(0.08) }
    var track: Color { isRetro ? Color.white.opacity(0.12) : Color.primary.opacity(0.12) }
    var tint: Color { isRetro ? Neon.cyan : .accentColor }
    var link: Color { isRetro ? Neon.cyan : Color(nsColor: .linkColor) }
    var titleWidth: Font.Width { isRetro ? .expanded : .standard }

    var countdownFont: Font {
        isRetro
            ? .system(size: 30, weight: .heavy, design: .monospaced)
            : .system(size: 28, weight: .semibold, design: .rounded)
    }

    var bannerTitleFont: Font {
        isRetro ? .system(size: 24, weight: .heavy) : .system(size: 26, weight: .semibold)
    }

    var bannerCountdownFont: Font {
        isRetro
            ? .system(size: 34, weight: .heavy, design: .monospaced)
            : .system(size: 34, weight: .semibold, design: .rounded)
    }

    var countdownStyle: AnyShapeStyle {
        isRetro
            ? AnyShapeStyle(LinearGradient(colors: [Neon.cyan, Neon.lavender, Neon.magenta], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(.primary)
    }

    func progressFill(_ meetingColor: Color) -> AnyShapeStyle {
        isRetro
            ? AnyShapeStyle(LinearGradient(colors: [Neon.magenta, Neon.cyan], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(meetingColor)
    }

    func joinFill(pressed: Bool) -> AnyShapeStyle {
        if isRetro {
            let colors = pressed ? [Neon.violet, Neon.magenta.opacity(0.8)] : [Neon.magenta, Neon.violet]
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(Color.accentColor.opacity(pressed ? 0.8 : 1))
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(theme: .classic)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct CardBackground: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if palette.isRetro {
            content
                .background(Neon.night.opacity(0.62), in: shape)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(colors: [Neon.magenta, Neon.violet, Neon.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                )
                .shadow(color: Neon.magenta.opacity(0.45), radius: 10)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

struct SynthwaveBackdrop: View {
    @Environment(\.colorSchemeContrast) private var contrast

    private static let stars: [(x: Double, y: Double, size: Double)] = [
        (0.08, 0.06, 1.6), (0.22, 0.14, 1.0), (0.37, 0.04, 1.3), (0.55, 0.11, 0.9),
        (0.68, 0.05, 1.5), (0.83, 0.13, 1.1), (0.93, 0.07, 0.8), (0.14, 0.24, 0.8),
        (0.47, 0.21, 1.2), (0.76, 0.25, 0.9), (0.30, 0.33, 0.7), (0.90, 0.31, 1.0),
    ]

    var body: some View {
        let dim = contrast == .increased ? 0.45 : 1.0
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Neon.night, Neon.dusk, Neon.horizon]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            for star in Self.stars {
                let r = star.size
                let dot = CGRect(x: star.x * size.width - r / 2, y: star.y * size.height - r / 2, width: r, height: r)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.7 * dim)))
            }

            let horizon = size.height * 0.78
            let sunRadius = min(size.width * 0.24, 90)
            let center = CGPoint(x: size.width / 2, y: horizon)

            context.drawLayer { layer in
                layer.opacity = 0.72 * dim
                layer.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)))
                let sun = CGRect(x: center.x - sunRadius, y: center.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)
                layer.fill(Path(ellipseIn: sun), with: .linearGradient(
                    Gradient(colors: [Neon.sunTop, Neon.magenta]),
                    startPoint: CGPoint(x: 0, y: sun.minY),
                    endPoint: CGPoint(x: 0, y: horizon)
                ))
                layer.blendMode = .destinationOut
                var gap: CGFloat = 2
                var y = horizon - sunRadius * 0.55
                while y < horizon {
                    layer.fill(Path(CGRect(x: sun.minX, y: y, width: sun.width, height: gap)), with: .color(.black))
                    y += gap + 6
                    gap += 1.2
                }
            }

            context.drawLayer { layer in
                layer.opacity = 0.5 * dim
                var grid = Path()
                let floor = size.height - horizon
                for i in -9...9 {
                    let x = center.x + CGFloat(i) * size.width * 0.16
                    grid.move(to: CGPoint(x: center.x + CGFloat(i) * 6, y: horizon))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for step in 0...7 {
                    let t = CGFloat(step) / 7
                    let y = horizon + floor * t * t
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                layer.stroke(grid, with: .color(Neon.magenta), lineWidth: 0.8)
            }
        }
        .accessibilityHidden(true)
    }
}
