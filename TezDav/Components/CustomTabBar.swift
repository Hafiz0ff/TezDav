import SwiftData
import SwiftUI

/// Kept as a compatibility wrapper for AppRootView. The visible tab bar is now
/// SwiftUI's native tab bar, which adopts Liquid Glass automatically on iOS 26.
struct CustomTabView<Content: View>: View {
    @Binding var selectedTab: Int
    private let content: Content

    init(selectedTab: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selectedTab = selectedTab
        self.content = content()
    }

    var body: some View {
        content
    }
}

struct TabContentView: View {
    @Binding var selectedTab: Int

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                tabView
                    .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                tabView
            }
        }
        .tint(Color.accentPrimary)
        .preferredColorScheme(.dark)
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            tabRoot { DashboardView() }
                .tabItem { Label("Главная", systemImage: "square.grid.2x2") }
                .tag(0)

            tabRoot { FormView() }
                .tabItem { Label("Форма", systemImage: "waveform.path.ecg") }
                .tag(1)

            tabRoot { RecordsView() }
                .tabItem { Label("Рекорды", systemImage: "trophy") }
                .tag(2)

            tabRoot { RouteListView() }
                .tabItem { Label("Карта", systemImage: "map") }
                .tag(3)

            tabRoot { ProfileView() }
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                .tag(4)
        }
    }

    private func tabRoot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView()
                content()
            }
        }
    }
}

struct CoachTabView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                DailyRecommendationCardView(
                    activities: activities,
                    settings: settings,
                    context: modelContext
                )
                .padding(.horizontal, DesignTokens.Spacing.screen)
                .padding(.top, DesignTokens.Spacing.md)
            }
            .padding(.bottom, 120)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Тренер")
    }
}
