import SwiftData
import SwiftUI
import GoogleMaps

var isRunningTests: Bool {
    if NSClassFromString("XCTestCase") != nil {
        return true
    }
    let env = ProcessInfo.processInfo.environment
    if env["XCTestConfigurationFilePath"] != nil || env.keys.contains(where: { $0.contains("XCTest") }) {
        return true
    }
    return false
}

@main
struct TezDavApp: App {
    init() {
        GMSServices.provideAPIKey("AIzaSyFakeKey_NoRealKeyNeededForTesting")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onAppear {
                    if CommandLine.arguments.contains("--seed-demo-data") {
                        // Force onboarding complete so the main UI shows
                        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                    }
                }
        }
        .modelContainer(Self.modelContainer)
    }

    static let modelContainer: ModelContainer = {
        let combinedSchema = Schema([
            Activity.self, ActivityStreamSample.self, SyncState.self, UserSettings.self,
            IntervalSegment.self, TrainingWeek.self, SavedRoute.self, Segment.self,
            SegmentEffort.self, PersonalSegment.self, GearItem.self, WeatherSnapshot.self,
            Achievement.self, FriendActivity.self, FriendComment.self, PlannedWorkout.self
        ])
        
        if isRunningTests {
            let testConfig = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: combinedSchema, configurations: testConfig)
            } catch {
                preconditionFailure("Failed to initialize SwiftData for testing: \(error)")
            }
        }
        
        let cloudConfig = ModelConfiguration(
            "TezDavCloud",
            schema: Schema([
                Activity.self, SyncState.self, UserSettings.self, IntervalSegment.self,
                TrainingWeek.self, SavedRoute.self, Segment.self, SegmentEffort.self,
                PersonalSegment.self, GearItem.self, WeatherSnapshot.self, Achievement.self,
                FriendActivity.self, FriendComment.self, PlannedWorkout.self
            ]),
            cloudKitDatabase: .none
        )

        let localConfig = ModelConfiguration(
            "TezDavLocal",
            schema: Schema([ActivityStreamSample.self]),
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: combinedSchema, configurations: [cloudConfig, localConfig])
        } catch {
            print("SwiftData Container creation failed. Attempting database wipe and recovery: \(error)")
            
            // Database wipe helper
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if let files = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                    for file in files {
                        let ext = file.pathExtension.lowercased()
                        if ext == "sqlite" || ext == "sqlite-wal" || ext == "sqlite-shm" || file.lastPathComponent.contains("TezDav") || file.lastPathComponent.contains("default") {
                            try? fm.removeItem(at: file)
                        }
                    }
                }
            }
            
            // Try one more time after wiping
            do {
                return try ModelContainer(for: combinedSchema, configurations: [cloudConfig, localConfig])
            } catch {
                preconditionFailure("Hard failure initializing SwiftData even after wipe: \(error)")
            }
        }
    }()
}
