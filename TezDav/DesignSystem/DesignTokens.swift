import SwiftUI

/// Shared visual constants for the TezDav Liquid Glass interface.
enum DesignTokens {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let compact: CGFloat = 10
        static let control: CGFloat = 14
        static let card: CGFloat = 24
        static let heroCard: CGFloat = 28
    }

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let regular: CGFloat = 1
    }

    enum Motion {
        static func selection(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)
        }

        static func content(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: 0.28)
        }
    }
}

extension Font {
    static func tezDavMetric(
        _ style: Font.TextStyle,
        weight: Font.Weight = .semibold
    ) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

private struct ReduceTransparencyPreviewKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    /// Preview-only override. Runtime behavior still follows the system setting.
    var tezDavReduceTransparencyOverride: Bool? {
        get { self[ReduceTransparencyPreviewKey.self] }
        set { self[ReduceTransparencyPreviewKey.self] = newValue }
    }
}
