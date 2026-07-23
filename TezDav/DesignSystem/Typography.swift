import SwiftUI

/// Dynamic Type based typography with rounded, tabular metrics.

// MARK: - Font Extensions

extension Font {

    // MARK: - SF Pro Display (Headings)

    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)

    static let title1 = Font.system(.title, design: .default, weight: .bold)

    static let title2 = Font.system(.title2, design: .default, weight: .semibold)

    static let title3 = Font.system(.title3, design: .default, weight: .semibold)

    // MARK: - SF Pro Text (Body)

    static let body = Font.system(.body, design: .default, weight: .regular)

    static let bodyEmphasized = Font.system(.body, design: .default, weight: .medium)

    static let callout = Font.system(.callout, design: .default, weight: .regular)

    static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)

    static let footnote = Font.system(.footnote, design: .default, weight: .regular)

    static let caption1 = Font.system(.caption, design: .default, weight: .regular)

    static let caption2 = Font.system(.caption2, design: .default, weight: .regular)

    // MARK: - Labels (Uppercase)

    /// Label large - 13px Semibold
    static let labelLarge = Font.system(size: 13, weight: .semibold, design: .default)

    /// Label medium - 12px Semibold
    static let labelMedium = Font.system(size: 12, weight: .semibold, design: .default)

    /// Label small - 11px Medium
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - SF Mono (Metrics & Numbers)

    static let metricHero = Font.system(.largeTitle, design: .rounded, weight: .bold)

    static let metricLarge = Font.system(.title, design: .rounded, weight: .bold)

    static let metricMedium = Font.system(.title2, design: .rounded, weight: .bold)

    static let metricRegular = Font.system(.title3, design: .rounded, weight: .bold)

    static let metricSmall = Font.system(.headline, design: .rounded, weight: .semibold)

    static let metricTiny = Font.system(.body, design: .rounded, weight: .semibold)

    // MARK: - Inline Numbers (for text with numbers)

    static let inlineNumber = Font.system(.callout, design: .rounded, weight: .semibold)
}

// MARK: - Text Styles with Tracking (Letter Spacing)

struct TezDavTextStyle {

    // MARK: - Heading Styles

    static func largeTitle(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle)
            .tracking(0)
    }

    static func title1(_ text: String) -> some View {
        Text(text)
            .font(.title1)
            .tracking(0)
    }

    static func title2(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .tracking(0)
    }

    static func title3(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .tracking(0)
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
            .tracking(0)
    }

    static func metricLarge(_ value: String) -> some View {
        Text(value)
            .font(.metricLarge)
            .tracking(0)
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
            .tracking(0)
            .monospacedDigit()
    }
}

struct LargeMetricModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.metricLarge)
            .tracking(0)
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
