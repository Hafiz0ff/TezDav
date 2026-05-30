import SwiftData
import SwiftUI

/// Story Feed Dashboard - New Design
/// Vertical feed of activity cards with elevated depth style
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
            switch selectedSport {
            case .all:
                return true
            case .run:
                return activity.sportType.lowercased().contains("run")
            case .ride:
                return activity.sportType.lowercased().contains("ride") || activity.sportType.lowercased().contains("cycl")
            case .walk:
                return activity.sportType.lowercased().contains("walk") || activity.sportType.lowercased().contains("hike")
            case .swim:
                return activity.sportType.lowercased().contains("swim")
            case .other:
                let type = activity.sportType.lowercased()
                return !type.contains("run") && !type.contains("ride") && !type.contains("cycl") && !type.contains("walk") && !type.contains("hike") && !type.contains("swim")
            }
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.lg)

                    // Quick Stats Bar
                    quickStatsBar
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.xl)

                    // Sport Filter Pills
                    sportFilterPills
                        .padding(.bottom, Spacing.lg)

                    // Activity Feed
                    activityFeed
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.xl)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Активности")
                    .font(.largeTitle)
                    .foregroundColor(.textPrimary)

                Text("Ваша история тренировок")
                    .font(.callout)
                    .foregroundColor(.textDisabled)
            }

            Spacer()

            // Profile Button
            Button {
                // Navigate to profile
            } label: {
                Circle()
                    .fill(Color.backgroundSecondary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.accentPrimary, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.accentPrimary)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 4)
            }
        }
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        let summary = DashboardViewModel.summary(from: activities)
        let readinessScore = 87 // TODO: Get from HealthKit

        return HStack(spacing: Spacing.lg) {
            quickStatItem(
                label: "Готовность",
                value: "\(readinessScore)%",
                isAccent: true
            )

            Divider()
                .frame(height: 40)
                .background(Color.backgroundTertiary)

            quickStatItem(
                label: "км неделя",
                value: String(format: "%.1f", summary.weeklyDistanceMeters / 1000.0),
                isAccent: false
            )

            Divider()
                .frame(height: 40)
                .background(Color.backgroundTertiary)

            quickStatItem(
                label: "Форма",
                value: String(format: "%+.0f", summary.tsb),
                isAccent: summary.tsb > 0
            )
        }
        .padding(Spacing.lg)
        .background(Color.backgroundSecondary)
        .cornerRadius(CornerRadius.regular)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.regular)
                .stroke(Color.backgroundTertiary, lineWidth: 1)
        )
    }

    private func quickStatItem(label: String, value: String, isAccent: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.metricRegular)
                .foregroundColor(isAccent ? .accentPrimary : .textPrimary)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundColor(.textDisabled)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sport Filter Pills

    private var sportFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(SportFilter.allCases, id: \.self) { sport in
                    Button {
                        HapticManager.trigger(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSport = sport
                        }
                    } label: {
                        Text(sport.displayName)
                            .pillBadge(isActive: selectedSport == sport)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        LazyVStack(spacing: Spacing.lg) {
            ForEach(Array(filteredActivities.enumerated()), id: \.element.stravaId) { index, activity in
                if index == 0 {
                    // First card - full with map preview
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        ActivityCardView(activity: activity)
                    }
                    .buttonStyle(CardButtonStyle())
                } else {
                    // Compact cards for older activities
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        CompactActivityCardView(activity: activity)
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }

            if filteredActivities.isEmpty {
                emptyStateView
                    .padding(.top, Spacing.xxxl)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "figure.run")
                .font(.system(size: 64))
                .foregroundColor(.textDisabled)
                .opacity(0.3)

            Text("Нет активностей")
                .font(.title3)
                .foregroundColor(.textSecondary)

            Text("Импортируйте GPX/FIT файлы или подключите Strava")
                .font(.callout)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxxl)
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StoryFeedDashboardView()
            .modelContainer(for: [Activity.self, UserSettings.self], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
