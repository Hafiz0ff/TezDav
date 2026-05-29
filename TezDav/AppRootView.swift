import SwiftData
import SwiftUI
import UserNotifications

struct ActivityIdWrapper: Identifiable {
    let id: Int64
}

struct FileIdWrapper: Identifiable {
    let id = UUID()
    let urls: [URL]
}

// Global delegate to handle notification taps and deep links
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()
    
    var onNotificationTap: ((Int64) -> Void)?
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let activityId = response.notification.request.content.userInfo["activityId"] as? Int64 {
            onNotificationTap?(activityId)
        } else if let activityIdStr = response.notification.request.content.userInfo["activityId"] as? String,
                  let activityId = Int64(activityIdStr) {
            onNotificationTap?(activityId)
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

struct AppRootView: View {
    @Query private var allActivities: [Activity]
    
    @State private var isConnected = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    @State private var activityIdWrapper: ActivityIdWrapper? = nil
    
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var importedFileURLs: [URL]? = nil

    private let config = StravaConfig.fromBundle()
    private let tokenStore = KeychainTokenStore()

    var body: some View {
        Group {
            if onboardingCompleted {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar.fill")
                        }
                        .tag(0)

                    FormView()
                        .tabItem {
                            Label("Form", systemImage: "waveform.path.ecg")
                        }
                        .tag(1)

                    RouteListView()
                        .tabItem {
                            Label("Routes", systemImage: "map.fill")
                        }
                        .tag(2)

                    RecordsView()
                        .tabItem {
                            Label("Records", systemImage: "trophy.fill")
                        }
                        .tag(3)
                        
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle.fill")
                        }
                        .tag(4)
                }
                .sheet(item: $activityIdWrapper) { wrapper in
                    if let targetAct = allActivities.first(where: { $0.stravaId == wrapper.id }) {
                        NavigationStack {
                            ActivityDetailView(activity: targetAct)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button("Закрыть") {
                                            activityIdWrapper = nil
                                        }
                                    }
                                }
                        }
                    }
                }
                .sheet(item: Binding(
                    get: { importedFileURLs.map { FileIdWrapper(urls: $0) } },
                    set: { wrapper in importedFileURLs = wrapper?.urls }
                )) { wrapper in
                    FileImportView(fileURLs: wrapper.urls)
                }
                .onOpenURL { url in
                    if url.scheme == "tezdav" {
                        handleDeepLink(url)
                    } else if url.isFileURL {
                        // Direct file import from Files or Share Sheet!
                        self.importedFileURLs = [url]
                    }
                }
            } else {
                Color.clear
                    .fullScreenCover(isPresented: Binding(get: { !onboardingCompleted }, set: { _ in })) {
                        OnboardingView(isConnected: $isConnected, onboardingCompleted: $onboardingCompleted)
                    }
                    .onAppear {
                        if (try? tokenStore.loadToken()) != nil {
                            isConnected = true
                        }
                    }
                    .onOpenURL { url in
                        if url.scheme == "tezdav" {
                            handleDeepLink(url)
                        } else if url.isFileURL {
                            // Direct file import from Files or Share Sheet!
                            self.importedFileURLs = [url]
                        }
                    }
            }
        }
        .onAppear {
            setupNotificationDelegate()
        }
    }

    private func connectStrava() {
        do {
            let state = UUID().uuidString
            let authURL = try StravaOAuth.authorizationURL(config: config, state: state)
            UIApplication.shared.open(authURL)
        } catch {
            errorMessage = "Failed to create authorization URL: \(error.localizedDescription)"
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "tezdav" else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let code = try StravaOAuth.authorizationCode(from: url)
                let refresher = StravaTokenRefresher(config: config)
                let token = try await refresher.exchangeCode(code)
                try tokenStore.saveToken(token)
                
                await MainActor.run {
                    isConnected = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Auth error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
        NotificationCenterDelegate.shared.onNotificationTap = { activityId in
            self.activityIdWrapper = ActivityIdWrapper(id: activityId)
            self.selectedTab = 0 // switch to Dashboard
        }
    }
}
