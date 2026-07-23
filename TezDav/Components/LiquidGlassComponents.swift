import SwiftUI

/// Opaque content surface. Data remains legible and never sits on a glass layer.
struct DataSurface<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(
        cornerRadius: CGFloat = DesignTokens.Radius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.contentSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.contentBorder, lineWidth: DesignTokens.Stroke.hairline)
            }
    }
}

struct MetricDataCard: View {
    let title: String
    let value: String
    let detail: String?
    let color: Color

    init(title: String, value: String, detail: String? = nil, color: Color) {
        self.title = title
        self.value = value
        self.detail = detail
        self.color = color
    }

    var body: some View {
        DataSurface(cornerRadius: DesignTokens.Radius.heroCard) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)

                Text(value)
                    .font(.tezDavMetric(.largeTitle, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct RecordValueRow: View {
    let title: String
    let date: String?
    let value: String?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                if let date {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            if let value {
                Text(value)
                    .font(.tezDavMetric(.body, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentPrimary)
            } else {
                Text("Нет данных")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                Color.textTertiary.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    }
            }
        }
        .contentShape(Rectangle())
    }
}

struct TezDavEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 64, height: 64)
                .liquidGlassControl(shape: .circle, tint: .emerald)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(LiquidGlassButtonStyle(prominent: true))
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: 420)
    }
}

struct GlassSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: DesignTokens.Spacing.xs) {
                    segments
                }
            } else {
                segments
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        .liquidGlassControl(shape: .capsule, tint: .neutral)
    }

    private var segments: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(options, id: \.self) { option in
                Button {
                    HapticManager.trigger(.light)
                    withAnimation(DesignTokens.Motion.selection(reduceMotion: reduceMotion)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selection == option ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(Color.accentPrimary.opacity(0.18))
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Liquid Glass Components") {
    ZStack {
        AmbientBackgroundView()
        VStack(spacing: DesignTokens.Spacing.md) {
            MetricDataCard(title: "Фитнес CTL", value: "47", detail: "+2 за неделю", color: .accentPrimary)
            TezDavEmptyState(
                symbol: "figure.run",
                title: "Нет тренировок",
                message: "Подключите Strava или импортируйте файл."
            )
        }
        .padding(DesignTokens.Spacing.screen)
    }
    .preferredColorScheme(.dark)
}
