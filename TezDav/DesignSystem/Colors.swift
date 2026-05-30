import SwiftUI

/// TezDav Design System - Color Palette
/// Dark Professional theme with Emerald Green accent
extension Color {

    // MARK: - Background Colors

    /// Primary background - Deep black (#0A0A0A)
    static let backgroundPrimary = Color(hex: "0A0A0A")

    /// Secondary background - Dark gray (#1A1A1A)
    static let backgroundSecondary = Color(hex: "1A1A1A")

    /// Tertiary background - Very dark gray (#2A2A2A)
    static let backgroundTertiary = Color(hex: "2A2A2A")

    // MARK: - Accent Colors

    /// Primary accent - Emerald green (#10B981)
    static let accentPrimary = Color(hex: "10B981")

    /// Dark accent - Dark emerald (#059669)
    static let accentDark = Color(hex: "059669")

    // MARK: - Text Colors

    /// Primary text - White (#FFFFFF)
    static let textPrimary = Color(hex: "FFFFFF")

    /// Secondary text - Light gray (#D1D5DB)
    static let textSecondary = Color(hex: "D1D5DB")

    /// Tertiary text - Gray (#9CA3AF)
    static let textTertiary = Color(hex: "9CA3AF")

    /// Disabled text - Dark gray (#6B7280)
    static let textDisabled = Color(hex: "6B7280")

    // MARK: - Semantic Colors

    /// Success color - Emerald green (#10B981)
    static let success = Color(hex: "10B981")

    /// Warning color - Amber (#F59E0B)
    static let warning = Color(hex: "F59E0B")

    /// Error color - Red (#EF4444)
    static let error = Color(hex: "EF4444")

    /// Info color - Blue (#3B82F6)
    static let info = Color(hex: "3B82F6")

    // MARK: - Sport Type Colors

    /// Running color - Emerald green
    static let sportRunning = Color(hex: "10B981")

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
    static let chartHeartRate = Color(hex: "EF4444")

    /// Pace/Speed chart color - Emerald green
    static let chartPace = Color(hex: "10B981")

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
