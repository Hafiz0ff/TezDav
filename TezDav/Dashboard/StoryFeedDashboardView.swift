import SwiftData
import SwiftUI

/// Story Feed Dashboard — Liquid Glass redesign.
/// Vertical feed of activity cards over an ambient emerald-tinted backdrop.
struct StoryFeedDashboardView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSport: SportFilter = .all

    private var activeUserSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    private var filteredActivities: [Activity] {
        activities.filter { activity in
            let type = activity.sportType.lowercased()
            switch selectedSport {
            case .all:
                return true
            case .run:
                return type.contains("run")
            case .ride:
                return type.contains("ride") || type.contains("cycl")
            case .walk:
                return type.contains("walk") || type.contains("hike")
            case .swim:
                return type.contains("swim")
            case .other:
                return !type.contains("run") && !type.contains("ride")
                    && !type.contains("cycl") && !type.contains("walk")
                    && !type.contains("hike") && !type.contains("swim")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                quickStatsBar
                    .padding(.horizontal, 22)

                sportFilterPills

                activityFeed
                    .padding(.horizontal, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 140)  // room for floating tab bar
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Активности")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.textOnGlass)
                    .tracking(-0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Ваша история тренировок")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondaryReadable)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Profile button — glass circle
            Button {
                // Navigate to profile
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.glassNeutralTint)
                    Circle()
                        .strokeBorder(Color.accentPrimary.opacity(0.6), lineWidth: 1.5)
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }
                .frame(width: 42, height: 42)
                .shadow(color: Color.accentPrimary.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        let summary = DashboardViewModel.summary(from: activities)
        let readinessScore = 87  // TODO: wire to HealthKit-derived readiness

        return HStack(spacing: 0) {
            quickStatItem(
                label: "Готовность",
                value: "\(readinessScore)%",
                isAccent: true
            )

            statDivider

            quickStatItem(
                label: activeUserSettings.isMetric ? "км неделя" : "ми неделя",
                value: weeklyDistanceString(summary.weeklyDistanceMeters),
                isAccent: false
            )

            statDivider

            quickStatItem(
                label: "Форма",
                value: String(format: "%+.0f", summary.tsb),
                isAccent: summary.tsb > 0
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .liquidGlassCard(cornerRadius: 20, tint: .neutral)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 36)
    }

    private func quickStatItem(label: String, value: String, isAccent: Bool) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(isAccent ? .accentPrimary : .textOnGlass)
                .shadow(
                    color: isAccent ? Color.accentPrimary.opacity(0.45) : .clear,
                    radius: isAccent ? 10 : 0
                )

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(.textSecondaryReadable)
        }
        .frame(maxWidth: .infinity)
    }

    private func weeklyDistanceString(_ meters: Double) -> String {
        let value = activeUserSettings.isMetric ? meters / 1000.0 : meters / 1609.34
        return String(format: "%.1f", value)
    }

    // MARK: - Sport Filter Pills

    private var sportFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SportFilter.allCases, id: \.self) { sport in
                    Button {
                        HapticManager.trigger(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                            selectedSport = sport
                        }
                    } label: {
                        Text(sport.displayName)
                            .font(.system(size: 14, weight: selectedSport == sport ? .bold : .semibold))
                            .foregroundColor(
                                selectedSport == sport ? .textOnGlass : .textSecondaryReadable
                            )
                            .padding(.vertical, 9)
                            .padding(.horizontal, 18)
                            .liquidGlassPill(isActive: selectedSport == sport)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        LazyVStack(spacing: 16) {
            if filteredActivities.isEmpty {
                emptyStateView
                    .padding(.top, 40)
            } else {
                ForEach(Array(filteredActivities.enumerated()), id: \.element.stravaId) { index, activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        if index == 0 {
                            ActivityCardView(activity: activity)
                        } else {
                            CompactActivityCardView(activity: activity)
                        }
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.glassEmeraldTint)
                    .frame(width: 100, height: 100)
                Circle()
                    .strokeBorder(Color.accentPrimary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image(systemName: "figure.run")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            .shadow(color: Color.accentPrimary.opacity(0.35), radius: 24, x: 0, y: 10)

            Text("Нет активностей")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textOnGlass)

            Text("Импортируйте GPX или FIT файл, либо подключите Strava — все ваши тренировки появятся здесь.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondaryReadable)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 22)
        .liquidGlassCard(cornerRadius: 22, tint: .neutral)
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AmbientBackgroundView()
        NavigationStack {
            StoryFeedDashboardView()
                .modelContainer(for: [Activity.self, UserSettings.self], inMemory: true)
        }
    }
    .preferredColorScheme(.dark)
}
