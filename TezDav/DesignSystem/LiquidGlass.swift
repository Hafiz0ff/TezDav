import SwiftUI

enum GlassTint {
    case neutral
    case emerald
    case emeraldStrong
    case ruby
}

enum LiquidGlassControlShape {
    case roundedRect(CGFloat)
    case capsule
    case circle
}

/// Compatibility card modifier. Despite the legacy name, content cards are matte,
/// opaque surfaces; Liquid Glass is reserved for navigation and controls.
struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: GlassTint
    let glow: Bool

    func body(content: Content) -> some View {
        let borderColor: Color = switch tint {
        case .emerald, .emeraldStrong:
            Color.accentPrimary.opacity(0.22)
        case .ruby:
            Color.ruby.opacity(0.22)
        case .neutral:
            Color.contentBorder
        }

        content
            .background(Color.contentSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: DesignTokens.Stroke.hairline)
            }
            .shadow(
                color: glow ? borderColor.opacity(0.25) : Color.black.opacity(0.22),
                radius: glow ? 16 : 8,
                x: 0,
                y: 6
            )
    }
}

struct LiquidGlassControlModifier: ViewModifier {
    let shape: LiquidGlassControlShape
    let tint: GlassTint
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.tezDavReduceTransparencyOverride) private var reduceTransparencyOverride
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparencyOverride ?? reduceTransparency {
            fallback(content: content, opaque: true)
        } else if #available(iOS 26.0, *) {
            native(content: content)
        } else {
            fallback(content: content, opaque: false)
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func native(content: Content) -> some View {
        let glass = interactive ? nativeGlass.interactive() : nativeGlass

        switch shape {
        case .roundedRect(let radius):
            content.glassEffect(glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            content.glassEffect(glass, in: Capsule())
        case .circle:
            content.glassEffect(glass, in: Circle())
        }
    }

    @available(iOS 26.0, *)
    private var nativeGlass: Glass {
        switch tint {
        case .neutral:
            return .regular
        case .emerald:
            return .regular.tint(Color.accentPrimary.opacity(0.28))
        case .emeraldStrong:
            return .regular.tint(Color.accentDark.opacity(0.62))
        case .ruby:
            return .regular.tint(Color.rubyDark.opacity(0.52))
        }
    }

    @ViewBuilder
    private func fallback(content: Content, opaque: Bool) -> some View {
        let fill = opaque
            ? AnyShapeStyle(Color.contentSurfaceRaised)
            : AnyShapeStyle(.ultraThinMaterial)
        let borderOpacity = contrast == .increased ? 0.3 : 0.14

        switch shape {
        case .roundedRect(let radius):
            content
                .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
                }
        case .capsule:
            content
                .background(fill, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
                }
        case .circle:
            content
                .background(fill, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
                }
        }
    }
}

struct LiquidGlassPillModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.liquidGlassControl(
            shape: .capsule,
            tint: isActive ? .emeraldStrong : .neutral
        )
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    let prominent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(prominent: Bool = false) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .liquidGlassControl(
                shape: .capsule,
                tint: prominent ? .emeraldStrong : .neutral
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(
                DesignTokens.Motion.selection(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

struct LiquidGlassTabBarContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .liquidGlassControl(shape: .capsule, tint: .neutral)
    }
}

/// Quiet canvas with only a slight semantic color cast in opposite corners.
struct AmbientBackgroundView: View {
    var body: some View {
        ZStack {
            Color.backgroundPrimary

            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.04), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 560
            )

            RadialGradient(
                colors: [Color.ruby.opacity(0.025), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = DesignTokens.Radius.card,
        tint: GlassTint = .neutral,
        glow: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                glow: glow
            )
        )
    }

    func liquidGlassPill(isActive: Bool = false) -> some View {
        modifier(LiquidGlassPillModifier(isActive: isActive))
    }

    func liquidGlassControl(
        shape: LiquidGlassControlShape,
        tint: GlassTint = .neutral,
        interactive: Bool = true
    ) -> some View {
        modifier(
            LiquidGlassControlModifier(
                shape: shape,
                tint: tint,
                interactive: interactive
            )
        )
    }
}
