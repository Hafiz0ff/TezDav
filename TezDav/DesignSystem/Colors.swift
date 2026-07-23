import SwiftUI

/// TezDav dark palette. Emerald and ruby are reserved for semantic data states.
extension Color {

    // MARK: - Background Colors

    /// Primary canvas (#0A0B0D)
    static let backgroundPrimary = Color(hex: "0A0B0D")

    /// Opaque content surface (#131416)
    static let backgroundSecondary = Color(hex: "131416")

    /// Raised content surface (#18191C)
    static let backgroundTertiary = Color(hex: "18191C")

    static let contentSurface = Color(hex: "131416")
    static let contentSurfaceRaised = Color(hex: "18191C")
    static let contentBorder = Color.white.opacity(0.1)

    // MARK: - Accent Colors

    /// Primary accent - Emerald green (#1DBF88)
    static let accentPrimary = Color(hex: "1DBF88")

    /// Dark accent - Dark emerald (#0D7A58)
    static let accentDark = Color(hex: "0D7A58")

    static let ruby = Color(hex: "C8304F")
    static let rubyDark = Color(hex: "8B1F35")

    // MARK: - Text Colors

    /// Primary text (#F5F6F7)
    static let textPrimary = Color(hex: "F5F6F7")

    /// Secondary text (#8E9196)
    static let textSecondary = Color(hex: "8E9196")

    /// Tertiary text (#71747A)
    static let textTertiary = Color(hex: "71747A")

    /// Disabled text - Dark gray (#6B7280)
    static let textDisabled = Color(hex: "6B7280")

    // MARK: - Semantic Colors

    /// Success color - Emerald green (#10B981)
    static let success = Color(hex: "1DBF88")

    /// Warning color - Amber (#F59E0B)
    static let warning = Color(hex: "F59E0B")

    /// Error color - Red (#EF4444)
    static let error = Color(hex: "C8304F")

    /// Info color - Blue (#3B82F6)
    static let info = Color(hex: "3B82F6")

    // MARK: - Sport Type Colors

    /// Running color - Emerald green
    static let sportRunning = Color(hex: "1DBF88")

    /// Cycling color - Blue
    static let sportCycling = Color(hex: "3B82F6")

    /// Swimming color - Cyan
    static let sportSwimming = Color(hex: "06B6D4")

    /// Triathlon color - Purple
    static let sportTriathlon = Color(hex: "8B5CF6")

    /// Other activities color - Gray
    static let sportOther = Color(hex: "6B7280")

    // MARK: - Chart Colors

    /// Heart rate chart color - Red
    static let chartHeartRate = Color(hex: "C8304F")

    /// Pace/Speed chart color - Emerald green
    static let chartPace = Color(hex: "1DBF88")

    /// Elevation chart color - Blue
    static let chartElevation = Color(hex: "3B82F6")

    /// Power chart color - Amber
    static let chartPower = Color(hex: "F59E0B")

    // MARK: - Gradient Helpers

    /// Primary accent gradient (Emerald)
    static let accentGradient = LinearGradient(
        colors: [accentPrimary, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent glow gradient (for elevated elements)
    static let accentGlowGradient = LinearGradient(
        colors: [
            accentPrimary.opacity(0.15),
            accentPrimary.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Map preview gradient (blue)
    static let mapPreviewGradient = LinearGradient(
        colors: [Color(hex: "1e3a8a"), Color(hex: "0f172a")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Liquid Glass Tokens

    /// Text on glass surfaces - bright white for maximum readability (21:1 contrast)
    static let textOnGlass = Color.white

    /// Secondary text on glass - light gray (12:1 contrast on dark)
    static let textSecondaryReadable = Color(hex: "A8ABB0")

    /// Tertiary text on glass - readable gray (7:1 contrast on dark)
    static let textTertiaryReadable = Color(hex: "8E9196")

    /// Thin glass border - subtle white edge for glass definition
    static let glassBorder = Color.white.opacity(0.14)

    /// Glass top inner highlight - simulates light refraction at top of glass
    static let glassHighlight = Color.white.opacity(0.22)

    /// Glass bottom inner shadow - subtle depth under glass
    static let glassInnerShadow = Color.black.opacity(0.35)

    // MARK: - App Ambient Backgrounds (under glass)

    /// Ambient background gradient - very dark with barely-perceptible emerald tint.
    /// Designed to be visible *through* glass cards while staying readable.
    static let ambientBackgroundGradient = RadialGradient(
        colors: [Color(hex: "0C1110"), Color.backgroundPrimary],
        center: .topTrailing,
        startRadius: 20,
        endRadius: 800
    )

    /// Compatibility token for existing screens; intentionally kept very subtle.
    static let emeraldAuroraGradient = RadialGradient(
        colors: [
            accentPrimary.opacity(0.04),
            accentPrimary.opacity(0.015),
            Color.clear
        ],
        center: .center,
        startRadius: 20,
        endRadius: 280
    )

    /// Glass tint - emerald-flavored translucent layer
    static let glassEmeraldTint = LinearGradient(
        colors: [
            accentPrimary.opacity(0.22),
            accentPrimary.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Glass neutral tint - frosted white wash for non-accent surfaces
    static let glassNeutralTint = LinearGradient(
        colors: [
            Color.white.opacity(0.14),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Sport Type Color Helper

extension Color {
    /// Returns the appropriate color for a given sport type
    static func forSportType(_ sportType: String) -> Color {
        switch sportType.lowercased() {
        case "run", "running", "бег":
            return .sportRunning
        case "ride", "cycling", "велоспорт":
            return .sportCycling
        case "swim", "swimming", "плавание":
            return .sportSwimming
        case "triathlon", "триатлон":
            return .sportTriathlon
        default:
            return .sportOther
        }
    }
}
