import SwiftUI
import SwiftData

/// Floating Liquid Glass Tab Bar.
/// Sits above content with safe-area padding, capsule shape, frosted glass background.
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String, tag: Int)] = [
        ("house.fill", "Главная", 0),
        ("chart.line.uptrend.xyaxis", "Форма", 1),
        ("trophy.fill", "Рекорды", 2),
        ("map.fill", "Карта", 3),
        ("person.crop.circle.fill", "Профиль", 4)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                tabButton(icon: tab.icon, label: tab.label, tag: tab.tag)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20) // Side padding for floating capsule style
        .padding(.bottom, -29) // Raised 5pt up as requested
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    @ViewBuilder
    private func tabButton(icon: String, label: String, tag: Int) -> some View {
        let isActive = selectedTab == tag

        Button {
            HapticManager.trigger(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isActive ? .bold : .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        isActive ? Color.accentPrimary : Color.textSecondaryReadable
                    )
                    .shadow(
                        color: isActive ? Color.accentPrimary.opacity(0.6) : .clear,
                        radius: isActive ? 10 : 0
                    )
                    .frame(height: 20)

                Text(label)
                    .font(.system(size: 9, weight: isActive ? .bold : .semibold))
                    .foregroundColor(
                        isActive ? Color.accentPrimary : Color.textSecondaryReadable
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .background(
                Group {
                    if isActive {
                        Capsule()
                            .fill(Color.glassEmeraldTint)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.accentPrimary.opacity(0.45), lineWidth: 1)
                            )
                    }
                }
            )
        }
        .buttonStyle(TabButtonStyle())
    }
}

// MARK: - Tab Button Style

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Container

struct CustomTabView<Content: View>: View {
    @Binding var selectedTab: Int
    let content: Content

    init(selectedTab: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selectedTab = selectedTab
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .ignoresSafeArea(edges: .bottom)
            CustomTabBar(selectedTab: $selectedTab)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Tab Content Switcher

struct TabContentView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ZStack {
            AmbientBackgroundView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Group {
                switch selectedTab {
                case 0:
                    NavigationStack { DashboardView() }
                case 1:
                    NavigationStack { FormView() }
                case 2:
                    NavigationStack { RecordsView() }
                case 3:
                    NavigationStack { RouteListView() }
                case 4:
                    NavigationStack { ProfileView() }
                default:
                    NavigationStack { DashboardView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Coach Tab View Wrapper

struct CoachTabView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Query private var userSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings {
        userSettings.first ?? UserSettings()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DailyRecommendationCardView(
                    activities: activities,
                    settings: settings,
                    context: modelContext
                )
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .padding(.bottom, 120)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Тренер")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
