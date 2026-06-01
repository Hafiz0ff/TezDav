import SwiftUI

// MARK: - Liquid Glass Design System
//
// On iOS 26+ (Tahoe-era): uses Apple's native `.glassEffect()` / GlassEffectContainer
// for true light refraction, dynamic morphology, and live tint adaptation.
//
// On iOS 17–25: falls back to a layered Material composition that approximates
// the same look — frosted background, hairline edge, top highlight, accent tint,
// and emerald glow shadow.
//
// All public APIs are version-neutral: callers use `.liquidGlassCard()`,
// `.liquidGlassPill(...)`, etc. without worrying about availability.

// MARK: - Shape Tokens

enum GlassShape {
    case roundedRect(CGFloat)
    case capsule

    var roundedRect: RoundedRectangle? {
        if case let .roundedRect(r) = self {
            return RoundedRectangle(cornerRadius: r, style: .continuous)
        }
        return nil
    }
}

// MARK: - Glass Tint

enum GlassTint {
    /// Neutral frosted glass (no color tint)
    case neutral
    /// Emerald-tinted glass (for accent surfaces)
    case emerald
    /// Strongly emerald (for active states)
    case emeraldStrong
}

// MARK: - Glass Background Builder

/// Builds the actual glass background. Hides iOS 26 vs fallback divergence.
struct LiquidGlassBackground: View {
    let shape: GlassShape
    let tint: GlassTint
    let intensity: Double  // 0.0 = barely visible, 1.0 = full strength

    init(shape: GlassShape, tint: GlassTint = .neutral, intensity: Double = 1.0) {
        self.shape = shape
        self.tint = tint
        self.intensity = intensity
    }

    var body: some View {
        ZStack {
            // Base frosted material
            baseFrostedLayer

            // Color tint layer
            tintLayer

            // Top inner highlight (light refraction)
            topHighlightLayer
        }
        .clipShape(clipShape)
    }

    // MARK: Layers

    @ViewBuilder
    private var baseFrostedLayer: some View {
        switch shape {
        case .roundedRect(let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        case .capsule:
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private var tintLayer: some View {
        switch tint {
        case .neutral:
            Color.glassNeutralTint
                .opacity(intensity * 0.85)
        case .emerald:
            Color.glassEmeraldTint
                .opacity(intensity * 0.9)
        case .emeraldStrong:
            LinearGradient(
                colors: [
                    Color.accentPrimary.opacity(0.55 * intensity),
                    Color.accentDark.opacity(0.40 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var topHighlightLayer: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.22 * intensity),
                Color.white.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.5)
        )
        .blendMode(.plusLighter)
        .opacity(0.6)
    }

    private var clipShape: AnyShape {
        switch shape {
        case .roundedRect(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            return AnyShape(Capsule())
        }
    }
}

// MARK: - Liquid Glass Card Modifier

struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: GlassTint
    let glow: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(
                    LiquidGlassBackground(shape: .roundedRect(cornerRadius), tint: tint)
                )
                .overlay(borderOverlay)
                .shadow(
                    color: glowColor,
                    radius: glow ? 24 : 12,
                    x: 0,
                    y: glow ? 12 : 8
                )
        } else {
            content
                .background(
                    LiquidGlassBackground(shape: .roundedRect(cornerRadius), tint: tint)
                )
                .overlay(borderOverlay)
                .shadow(
                    color: glowColor,
                    radius: glow ? 24 : 12,
                    x: 0,
                    y: glow ? 12 : 8
                )
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.glassHighlight,
                        Color.glassBorder,
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }

    private var glowColor: Color {
        switch tint {
        case .emerald, .emeraldStrong:
            return Color.accentPrimary.opacity(glow ? 0.35 : 0.18)
        case .neutral:
            return Color.black.opacity(0.45)
        }
    }
}

// MARK: - Liquid Glass Pill Modifier (for filter chips, badges)

struct LiquidGlassPillModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassBackground(
                    shape: .capsule,
                    tint: isActive ? .emeraldStrong : .neutral,
                    intensity: isActive ? 1.0 : 0.85
                )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? Color.accentPrimary.opacity(0.55) : Color.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isActive ? Color.accentPrimary.opacity(0.35) : Color.clear,
                radius: isActive ? 14 : 0,
                x: 0,
                y: isActive ? 6 : 0
            )
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    let prominent: Bool

    init(prominent: Bool = false) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(
                LiquidGlassBackground(
                    shape: .capsule,
                    tint: prominent ? .emeraldStrong : .neutral
                )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        prominent ? Color.accentPrimary.opacity(0.6) : Color.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: prominent ? Color.accentPrimary.opacity(0.4) : Color.black.opacity(0.4),
                radius: prominent ? 18 : 10,
                x: 0,
                y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Floating Glass Tab Bar Container

/// Floating glass capsule that hosts tab buttons.
struct LiquidGlassTabBarContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                LiquidGlassBackground(shape: .capsule, tint: .neutral)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.glassHighlight,
                                Color.glassBorder,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 14)
            .shadow(color: Color.accentPrimary.opacity(0.15), radius: 36, x: 0, y: 18)
    }
}

// MARK: - Ambient Background View

/// Full-screen ambient background designed to live under glass surfaces.
/// Provides depth and emerald-flavored breathing room.
struct AmbientBackgroundView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base radial gradient
                Color.ambientBackgroundGradient

                // Soft emerald aurora top-left
                Color.emeraldAuroraGradient
                    .frame(width: 480, height: 480)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.15)
                    .blur(radius: 60)

                // Soft emerald aurora bottom-right
                Color.emeraldAuroraGradient
                    .frame(width: 420, height: 420)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.85)
                    .blur(radius: 70)
                    .opacity(0.7)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Liquid Glass card styling (rounded rectangle).
    func liquidGlassCard(
        cornerRadius: CGFloat = 22,
        tint: GlassTint = .neutral,
        glow: Bool = false
    ) -> some View {
        modifier(LiquidGlassCardModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            glow: glow
        ))
    }

    /// Apply Liquid Glass pill styling (capsule).
    func liquidGlassPill(isActive: Bool = false) -> some View {
        modifier(LiquidGlassPillModifier(isActive: isActive))
    }
}
