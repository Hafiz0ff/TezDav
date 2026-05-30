import SwiftData
import SwiftUI
import UserNotifications
import CoreSpotlight

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
    @State private var sidebarSelection: Int? = 0
    @State private var activityIdWrapper: ActivityIdWrapper? = nil
    
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var importedFileURLs: [URL]? = nil
    @State private var isSystemFileImporterPresented = false

    private let config = StravaConfig.fromBundle()
    private let tokenStore = KeychainTokenStore()

    var body: some View {
        Group {
            if onboardingCompleted {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NavigationSplitView {
                        List(selection: $sidebarSelection) {
                            NavigationLink(value: 0) {
                                Label("Dashboard", systemImage: "chart.bar.fill")
                            }
                            NavigationLink(value: 1) {
                                Label("Form", systemImage: "waveform.path.ecg")
                            }
                            NavigationLink(value: 2) {
                                Label("Routes", systemImage: "map.fill")
                            }
                            NavigationLink(value: 3) {
                                Label("Social", systemImage: "person.2.fill")
                            }
                            NavigationLink(value: 4) {
                                Label("Records", systemImage: "trophy.fill")
                            }
                            NavigationLink(value: 5) {
                                Label("Profile", systemImage: "person.crop.circle.fill")
                            }
                        }
                        .navigationTitle("TezDav")
                        .listStyle(.sidebar)
                    } detail: {
                        switch sidebarSelection ?? 0 {
                        case 0: DashboardView()
                        case 1: FormView()
                        case 2: RouteListView()
                        case 3: SocialFeedView()
                        case 4: RecordsView()
                        case 5: ProfileView()
                        default: DashboardView()
                        }
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
                    .fileImporter(
                        isPresented: $isSystemFileImporterPresented,
                        allowedContentTypes: [.init(filenameExtension: "gpx")!, .init(filenameExtension: "fit")!],
                        allowsMultipleSelection: true
                    ) { result in
                        if case .success(let urls) = result {
                            self.importedFileURLs = urls
                        }
                    }
                    .onOpenURL { url in
                        if url.scheme == "tezdav" {
                            if url.host == "import" {
                                isSystemFileImporterPresented = true
                            } else {
                                handleDeepLink(url)
                            }
                        } else if url.isFileURL {
                            self.importedFileURLs = [url]
                        }
                    }
                } else {
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

                        SocialFeedView()
                            .tabItem {
                                Label("Social", systemImage: "person.2.fill")
                            }
                            .tag(3)

                        RecordsView()
                            .tabItem {
                                Label("Records", systemImage: "trophy.fill")
                            }
                            .tag(4)
                            
                        ProfileView()
                            .tabItem {
                                Label("Profile", systemImage: "person.crop.circle.fill")
                            }
                            .tag(5)
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
                    .fileImporter(
                        isPresented: $isSystemFileImporterPresented,
                        allowedContentTypes: [.init(filenameExtension: "gpx")!, .init(filenameExtension: "fit")!],
                        allowsMultipleSelection: true
                    ) { result in
                        if case .success(let urls) = result {
                            self.importedFileURLs = urls
                        }
                    }
                    .onOpenURL { url in
                        if url.scheme == "tezdav" {
                            if url.host == "import" {
                                isSystemFileImporterPresented = true
                            } else {
                                handleDeepLink(url)
                            }
                        } else if url.isFileURL {
                            self.importedFileURLs = [url]
                        }
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
                            self.importedFileURLs = [url]
                        }
                    }
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                let parts = uniqueIdentifier.split(separator: "-")
                if parts.count == 2, parts[0] == "activity", let activityId = Int64(parts[1]) {
                    self.activityIdWrapper = ActivityIdWrapper(id: activityId)
                    self.selectedTab = 0
                    self.sidebarSelection = 0
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
