import SwiftUI

/// Custom Tab Bar with Elevated Depth Style
/// Emerald green accent with glassmorphism effect
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton(
                icon: "chart.bar.fill",
                label: "Активности",
                tag: 0
            )

            tabButton(
                icon: "chart.xyaxis.line",
                label: "Аналитика",
                tag: 1
            )

            tabButton(
                icon: "map.fill",
                label: "Маршруты",
                tag: 2
            )

            tabButton(
                icon: "brain.head.profile",
                label: "Тренер",
                tag: 3
            )

            tabButton(
                icon: "person.crop.circle.fill",
                label: "Профиль",
                tag: 4
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            ZStack {
                // Glassmorphism background
                Color.backgroundSecondary
                    .opacity(0.95)

                // Blur effect
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.backgroundTertiary)
                .frame(height: 1),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: -4)
    }

    private func tabButton(icon: String, label: String, tag: Int) -> some View {
        Button {
            HapticManager.trigger(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tag {
                        // Active state - gradient background with glow
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentGradient)
                            .frame(width: 28, height: 28)
                            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 6, x: 0, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    .padding(1)
                            )
                    }

                    Image(systemName: icon)
                        .font(.system(size: selectedTab == tag ? 16 : 18))
                        .foregroundColor(selectedTab == tag ? .black : .textDisabled)
                        .opacity(selectedTab == tag ? 1.0 : 0.5)
                }
                .frame(width: 28, height: 28)

                Text(label)
                    .font(.system(size: 11, weight: selectedTab == tag ? .semibold : .regular))
                    .foregroundColor(selectedTab == tag ? .accentPrimary : .textDisabled)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(TabButtonStyle())
    }
}

// MARK: - Tab Button Style

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Custom Tab View Container

struct CustomTabView<Content: View>: View {
    @Binding var selectedTab: Int
    let content: Content

    init(selectedTab: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selectedTab = selectedTab
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            content

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}

// MARK: - Tab Content Container

struct TabContentView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        StoryFeedDashboardView()
                    }
                case 1:
                    NavigationStack {
                        FormView()
                    }
                case 2:
                    NavigationStack {
                        RouteListView()
                    }
                case 3:
                    NavigationStack {
                        CoachingInsightsView()
                    }
                case 4:
                    NavigationStack {
                        ProfileView()
                    }
                default:
                    NavigationStack {
                        StoryFeedDashboardView()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedTab = 0

    CustomTabView(selectedTab: $selectedTab) {
        TabContentView(selectedTab: $selectedTab)
    }
    .preferredColorScheme(.dark)
}
