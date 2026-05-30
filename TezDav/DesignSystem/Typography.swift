import SwiftUI

/// TezDav Design System - Typography
/// Hybrid system: SF Pro for text, SF Mono for metrics

// MARK: - Font Extensions

extension Font {

    // MARK: - SF Pro Display (Headings)

    /// Large title - 32px Bold
    static let largeTitle = Font.system(size: 32, weight: .bold, design: .default)

    /// Title 1 - 28px Bold
    static let title1 = Font.system(size: 28, weight: .bold, design: .default)

    /// Title 2 - 24px Semibold
    static let title2 = Font.system(size: 24, weight: .semibold, design: .default)

    /// Title 3 - 20px Semibold
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

    // MARK: - SF Pro Text (Body)

    /// Body - 17px Regular
    static let body = Font.system(size: 17, weight: .regular, design: .default)

    /// Body emphasized - 17px Medium
    static let bodyEmphasized = Font.system(size: 17, weight: .medium, design: .default)

    /// Callout - 15px Regular
    static let callout = Font.system(size: 15, weight: .regular, design: .default)

    /// Subheadline - 14px Regular
    static let subheadline = Font.system(size: 14, weight: .regular, design: .default)

    /// Footnote - 13px Regular
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)

    /// Caption 1 - 12px Regular
    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)

    /// Caption 2 - 11px Regular
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Labels (Uppercase)

    /// Label large - 13px Semibold
    static let labelLarge = Font.system(size: 13, weight: .semibold, design: .default)

    /// Label medium - 12px Semibold
    static let labelMedium = Font.system(size: 12, weight: .semibold, design: .default)

    /// Label small - 11px Medium
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - SF Mono (Metrics & Numbers)

    /// Hero metric - 48px Bold (for main metrics)
    static let metricHero = Font.system(size: 48, weight: .bold, design: .monospaced)

    /// Large metric - 36px Bold
    static let metricLarge = Font.system(size: 36, weight: .bold, design: .monospaced)

    /// Medium metric - 24px Bold
    static let metricMedium = Font.system(size: 24, weight: .bold, design: .monospaced)

    /// Regular metric - 20px Bold
    static let metricRegular = Font.system(size: 20, weight: .bold, design: .monospaced)

    /// Small metric - 18px Semibold
    static let metricSmall = Font.system(size: 18, weight: .semibold, design: .monospaced)

    /// Tiny metric - 16px Semibold
    static let metricTiny = Font.system(size: 16, weight: .semibold, design: .monospaced)

    // MARK: - Inline Numbers (for text with numbers)

    /// Inline number - 15px Semibold (for numbers in body text)
    static let inlineNumber = Font.system(size: 15, weight: .semibold, design: .monospaced)
}

// MARK: - Text Styles with Tracking (Letter Spacing)

struct TezDavTextStyle {

    // MARK: - Heading Styles

    static func largeTitle(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle)
            .tracking(-0.5)
    }

    static func title1(_ text: String) -> some View {
        Text(text)
            .font(.title1)
            .tracking(-0.5)
    }

    static func title2(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .tracking(-0.3)
    }

    static func title3(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .tracking(-0.3)
    }

    // MARK: - Label Styles (Uppercase with tracking)

    static func labelLarge(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.labelLarge)
            .tracking(0.5)
    }

    static func labelMedium(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.labelMedium)
            .tracking(0.5)
    }

    static func labelSmall(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.labelSmall)
            .tracking(0.8)
    }

    // MARK: - Metric Styles

    static func metricHero(_ value: String) -> some View {
        Text(value)
            .font(.metricHero)
            .tracking(-1.0)
    }

    static func metricLarge(_ value: String) -> some View {
        Text(value)
            .font(.metricLarge)
            .tracking(-0.8)
    }

    static func metricMedium(_ value: String) -> some View {
        Text(value)
            .font(.metricMedium)
            .tracking(0)
    }

    static func metricRegular(_ value: String) -> some View {
        Text(value)
            .font(.metricRegular)
            .tracking(0)
    }
}

// MARK: - View Modifiers for Typography

struct HeroMetricModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.metricHero)
            .tracking(-1.0)
            .monospacedDigit()
    }
}

struct LargeMetricModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.metricLarge)
            .tracking(-0.8)
            .monospacedDigit()
    }
}

struct MediumMetricModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.metricMedium)
            .monospacedDigit()
    }
}

struct RegularMetricModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.metricRegular)
            .monospacedDigit()
    }
}

struct LabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.labelSmall)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

extension View {
    /// Apply hero metric style (48px SF Mono Bold)
    func heroMetric() -> some View {
        modifier(HeroMetricModifier())
    }

    /// Apply large metric style (36px SF Mono Bold)
    func largeMetric() -> some View {
        modifier(LargeMetricModifier())
    }

    /// Apply medium metric style (24px SF Mono Bold)
    func mediumMetric() -> some View {
        modifier(MediumMetricModifier())
    }

    /// Apply regular metric style (20px SF Mono Bold)
    func regularMetric() -> some View {
        modifier(RegularMetricModifier())
    }

    /// Apply label style (11px SF Pro Medium, uppercase, tracking)
    func labelStyle() -> some View {
        modifier(LabelModifier())
    }
}
