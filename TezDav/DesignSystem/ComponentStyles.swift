import SwiftUI

/// TezDav Design System - Component Styles
/// Elevated Depth style with shadows and glows

// MARK: - Spacing System (8px grid)

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 10
    static let regular: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 20
    static let pill: CGFloat = 20
    static let circle: CGFloat = 50 // percentage
}

// MARK: - Shadows

struct TezDavShadow {
    /// Elevated card shadow (deep, prominent)
    static let elevated = Shadow(
        color: Color.black.opacity(0.5),
        radius: 20,
        x: 0,
        y: 12
    )

    /// Card shadow (standard)
    static let card = Shadow(
        color: Color.black.opacity(0.4),
        radius: 12,
        x: 0,
        y: 8
    )

    /// Button shadow
    static let button = Shadow(
        color: Color.black.opacity(0.3),
        radius: 6,
        x: 0,
        y: 4
    )

    /// Accent glow (emerald green)
    static let accentGlow = Shadow(
        color: Color.accentPrimary.opacity(0.4),
        radius: 12,
        x: 0,
        y: 4
    )

    /// Strong accent glow
    static let accentGlowStrong = Shadow(
        color: Color.accentPrimary.opacity(0.5),
        radius: 24,
        x: 0,
        y: 8
    )

    /// Tab bar shadow
    static let tabBar = Shadow(
        color: Color.black.opacity(0.3),
        radius: 10,
        x: 0,
        y: -4
    )
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers for Component Styles

// MARK: Card Styles

struct ElevatedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(Color.backgroundTertiary, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 12)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(Color.backgroundTertiary, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 8)
    }
}

struct MetricCardModifier: ViewModifier {
    let isAccent: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if isAccent {
                        Color.accentGlowGradient
                    } else {
                        Color.backgroundPrimary
                    }
                }
            )
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isAccent ? Color.accentPrimary.opacity(0.3) : Color.backgroundTertiary,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isAccent ? Color.accentPrimary.opacity(0.1) : Color.black.opacity(0.3),
                radius: isAccent ? 6 : 2,
                x: 0,
                y: isAccent ? 4 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.white.opacity(isAccent ? 0.1 : 0), lineWidth: 1)
                    .padding(1)
            )
    }
}

struct InsightCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.accentGlowGradient)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.accentPrimary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.accentPrimary.opacity(0.1), radius: 6, x: 0, y: 4)
    }
}

// MARK: Button Styles

struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.black)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.accentGradient)
            .cornerRadius(CornerRadius.regular)
            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.regular)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .padding(1)
            )
    }
}

struct SecondaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.textPrimary)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.regular)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.regular)
                    .stroke(Color.backgroundTertiary, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 4)
    }
}

// MARK: Badge Styles

struct BadgeModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isActive ? .black : .textTertiary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isActive {
                        Color.accentGradient
                    } else {
                        Color.backgroundSecondary
                    }
                }
            )
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(isActive ? Color.clear : Color.backgroundTertiary, lineWidth: 1)
            )
            .shadow(
                color: isActive ? Color.accentPrimary.opacity(0.4) : Color.clear,
                radius: isActive ? 6 : 0,
                x: 0,
                y: isActive ? 4 : 0
            )
    }
}

struct PillBadgeModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: isActive ? .semibold : .medium))
            .foregroundColor(isActive ? .black : .textTertiary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Group {
                    if isActive {
                        Color.accentGradient
                    } else {
                        Color.backgroundSecondary
                    }
                }
            )
            .cornerRadius(CornerRadius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.pill)
                    .stroke(isActive ? Color.clear : Color.backgroundTertiary, lineWidth: 1)
            )
            .shadow(
                color: isActive ? Color.accentPrimary.opacity(0.4) : Color.clear,
                radius: isActive ? 6 : 0,
                x: 0,
                y: isActive ? 4 : 0
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply elevated card style (deep shadows, prominent)
    func elevatedCard() -> some View {
        modifier(ElevatedCardModifier())
    }

    /// Apply standard card style
    func card() -> some View {
        modifier(CardModifier())
    }

    /// Apply metric card style
    func metricCard(isAccent: Bool = false) -> some View {
        modifier(MetricCardModifier(isAccent: isAccent))
    }

    /// Apply insight card style (emerald glow)
    func insightCard() -> some View {
        modifier(InsightCardModifier())
    }

    /// Apply primary button style
    func primaryButton() -> some View {
        modifier(PrimaryButtonModifier())
    }

    /// Apply secondary button style
    func secondaryButton() -> some View {
        modifier(SecondaryButtonModifier())
    }

    /// Apply badge style
    func badge(isActive: Bool = false) -> some View {
        modifier(BadgeModifier(isActive: isActive))
    }

    /// Apply pill badge style
    func pillBadge(isActive: Bool = false) -> some View {
        modifier(PillBadgeModifier(isActive: isActive))
    }
}

// Note: MapPreviewBackground is now defined in ActivityCardView.swift.
