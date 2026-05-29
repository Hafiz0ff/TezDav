# TezDav iOS Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compiling iOS 17 SwiftUI foundation for TezDav with local SwiftData storage, Strava auth/API scaffolding, sync orchestration, training metrics, and a local dashboard.

**Architecture:** The app is split into SwiftUI app shell, auth/session, Strava API, sync, persistence, metrics, and dashboard modules. Pure calculation and URL/rate-limit behavior is covered by unit tests; UI and Xcode project scaffolding are verified by `xcodebuild`.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, AuthenticationServices, Security/Keychain, XCTest, iOS 17.

---

### Task 1: Project Scaffold

**Files:**
- Create: `TezDav.xcodeproj/project.pbxproj`
- Create: `TezDav/Info.plist`
- Create: `TezDav/TezDavApp.swift`
- Create: `TezDav/AppRootView.swift`
- Create: `TezDavTests/TezDavTests.swift`

- [ ] Create a minimal iOS app Xcode project with app and unit test targets.
- [ ] Add a SwiftUI app entry point backed by a SwiftData model container.
- [ ] Add a smoke unit test that imports the app module.
- [ ] Run `xcodebuild -scheme TezDav -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### Task 2: Training Metrics

**Files:**
- Create: `TezDav/TrainingMetrics/TrainingLoadCalculator.swift`
- Create: `TezDavTests/TrainingLoadCalculatorTests.swift`

- [ ] Write failing tests for TRIMP, activity load fallback, and CTL/ATL/TSB calculations.
- [ ] Run the metrics test file and verify it fails because the calculator is missing.
- [ ] Implement deterministic pure Swift metric calculations.
- [ ] Run the metrics test file and verify it passes.

### Task 3: Persistence Models

**Files:**
- Create: `TezDav/Persistence/Activity.swift`
- Create: `TezDav/Persistence/ActivityStreamSample.swift`
- Create: `TezDav/Persistence/SyncState.swift`
- Create: `TezDav/Persistence/UserSettings.swift`
- Modify: `TezDav/TezDavApp.swift`

- [ ] Add SwiftData models for imported activities, stream samples, sync state, and user settings.
- [ ] Register all models in the app model container.
- [ ] Add an in-memory SwiftData unit test that inserts and fetches an activity.

### Task 4: Auth and Keychain

**Files:**
- Create: `TezDav/Auth/StravaConfig.swift`
- Create: `TezDav/Auth/StravaOAuth.swift`
- Create: `TezDav/Auth/TokenStore.swift`
- Create: `TezDav/Auth/KeychainTokenStore.swift`
- Create: `TezDav/Auth/StravaSession.swift`
- Create: `TezDavTests/StravaOAuthTests.swift`

- [ ] Write failing tests for OAuth URL scope, redirect URI, and token expiry refresh decisions.
- [ ] Implement config validation, OAuth URL construction, token models, and Keychain token persistence.
- [ ] Run auth tests and verify they pass.

### Task 5: Strava API and Rate Limit Queue

**Files:**
- Create: `TezDav/StravaAPI/RateLimitQueue.swift`
- Create: `TezDav/StravaAPI/StravaAPIClient.swift`
- Create: `TezDav/StravaAPI/StravaDTOs.swift`
- Create: `TezDavTests/RateLimitQueueTests.swift`

- [ ] Write failing tests proving that the queue allows requests under budget and delays when exhausted.
- [ ] Implement lightweight rate budget tracking and typed Strava DTOs/endpoints.
- [ ] Run queue tests and verify they pass.

### Task 6: Sync Service

**Files:**
- Create: `TezDav/Sync/SyncService.swift`
- Create: `TezDav/Sync/SyncProgress.swift`
- Create: `TezDavTests/SyncServiceTests.swift`

- [ ] Write a failing test that imports two API activities into an in-memory SwiftData context and records sync progress.
- [ ] Implement sync orchestration with API protocols, pagination hooks, metric calculation, and upsert behavior.
- [ ] Run sync tests and verify they pass.

### Task 7: Dashboard UI

**Files:**
- Create: `TezDav/Dashboard/DashboardView.swift`
- Create: `TezDav/Dashboard/DashboardViewModel.swift`
- Modify: `TezDav/AppRootView.swift`

- [ ] Add Dashboard summary view model that derives current CTL/ATL/TSB, weekly distance/time, and latest activities from local models.
- [ ] Add SwiftUI dashboard with sync status, metric tiles, weekly summary, and last five activities.
- [ ] Wire unauthenticated onboarding and authenticated dashboard shell.
- [ ] Run full `xcodebuild test`.

### Task 8: Verification

**Files:**
- Modify only files touched by failing verification.

- [ ] Run `xcodebuild -scheme TezDav -destination 'platform=iOS Simulator,name=iPhone 16' test`.
- [ ] Run `rg -n "TODO|TBD|fatalError|placeholder" TezDav TezDavTests docs/superpowers`.
- [ ] Confirm the app has no analytics SDK, backend configuration, or committed Strava secrets.
