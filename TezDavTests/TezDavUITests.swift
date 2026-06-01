import XCTest

final class TezDavUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Сценарий 1 — Первый запуск
    func testFirstLaunchOnboardingFlow() throws {
        // App starts and shows Onboarding Step 1
        let step1NextButton = app.buttons["onboarding_next_button"]
        XCTAssertTrue(step1NextButton.waitForExistence(timeout: 5.0))
        step1NextButton.tap()
        
        // Onboarding Step 2: Skip Strava Connect
        let skipStravaButton = app.buttons["onboarding_skip_strava_button"]
        XCTAssertTrue(skipStravaButton.waitForExistence(timeout: 5.0))
        skipStravaButton.tap()
        
        // Onboarding Step 3: Input heart rate and save
        let hrTextField = app.textFields["onboarding_hr_textfield"]
        XCTAssertTrue(hrTextField.waitForExistence(timeout: 5.0))
        hrTextField.tap()
        hrTextField.typeText("185")
        
        let saveButton = app.buttons["onboarding_save_button"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        
        // Dashboard displays with empty state
        let emptyStateText = app.staticTexts["dashboard_empty_state_label"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Сценарий 2 — Импорт GPX
    func testGPXFileImportFlow() throws {
        // Tap on add button
        let addButton = app.buttons["dashboard_add_activity_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0))
        addButton.tap()
        
        // Select GPX File Import option
        let importGPXOption = app.buttons["import_gpx_option"]
        XCTAssertTrue(importGPXOption.waitForExistence(timeout: 5.0))
        importGPXOption.tap()
        
        // Simulate tapping on the sample GPX file (simulated under UI testing environment)
        let sampleFileElement = app.staticTexts["sample_run.gpx"]
        XCTAssertTrue(sampleFileElement.waitForExistence(timeout: 5.0))
        sampleFileElement.tap()
        
        // Activity appears in list
        let runRow = app.buttons["activity_row_Sample Run"]
        XCTAssertTrue(runRow.waitForExistence(timeout: 5.0))
        runRow.tap()
        
        // Detail view displays route map
        let routeMap = app.otherElements["activity_detail_map"]
        XCTAssertTrue(routeMap.waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Сценарий 3 — Смена режима
    func testAppModeToggleFlow() throws {
        // Go to Profile screen
        let profileTabButton = app.tabBars.buttons["profile_tab_button"]
        XCTAssertTrue(profileTabButton.waitForExistence(timeout: 5.0))
        profileTabButton.tap()
        
        // Settings Section
        let settingsButton = app.buttons["profile_settings_button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5.0))
        settingsButton.tap()
        
        // Switch to Casual Mode
        let modeSegmentedControl = app.segmentedControls["app_mode_selector"]
        XCTAssertTrue(modeSegmentedControl.waitForExistence(timeout: 5.0))
        modeSegmentedControl.buttons["Casual"].tap()
        
        // Return to Dashboard
        let dashboardTabButton = app.tabBars.buttons["dashboard_tab_button"]
        XCTAssertTrue(dashboardTabButton.waitForExistence(timeout: 5.0))
        dashboardTabButton.tap()
        
        // Verify CTL/ATL/TSB cards are hidden
        XCTAssertFalse(app.staticTexts["dashboard_ctl_label"].exists)
        XCTAssertFalse(app.staticTexts["dashboard_tsb_label"].exists)
        
        // Switch back to Pro Mode
        profileTabButton.tap()
        settingsButton.tap()
        modeSegmentedControl.buttons["Pro"].tap()
        dashboardTabButton.tap()
        
        // Verify CTL/ATL/TSB are visible again
        XCTAssertTrue(app.staticTexts["dashboard_ctl_label"].waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Сценарий 4 — Создание личного сегмента
    func testCreatePersonalSegmentFlow() throws {
        // Navigate to details of a running activity
        let runRow = app.buttons["activity_row_Sample Run"]
        XCTAssertTrue(runRow.waitForExistence(timeout: 5.0))
        runRow.tap()
        
        // Tap on segment creation button
        let createSegmentButton = app.buttons["create_segment_button"]
        XCTAssertTrue(createSegmentButton.waitForExistence(timeout: 5.0))
        createSegmentButton.tap()
        
        // In the Segment Editor, set start and end positions, and name
        let segmentNameField = app.textFields["segment_name_field"]
        XCTAssertTrue(segmentNameField.waitForExistence(timeout: 5.0))
        segmentNameField.tap()
        segmentNameField.typeText("Тестовый подъём")
        
        let saveSegmentButton = app.buttons["segment_save_button"]
        saveSegmentButton.tap()
        
        // Go to Records screen
        let recordsTabButton = app.tabBars.buttons["records_tab_button"]
        XCTAssertTrue(recordsTabButton.waitForExistence(timeout: 5.0))
        recordsTabButton.tap()
        
        // Check that personal segment exists
        let segmentNameLabel = app.staticTexts["Тестовый подъём"]
        XCTAssertTrue(segmentNameLabel.waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Сценарий 5 — Шаринг карточки
    func testWorkoutShareSheetFlow() throws {
        // Navigate to details
        let runRow = app.buttons["activity_row_Sample Run"]
        XCTAssertTrue(runRow.waitForExistence(timeout: 5.0))
        runRow.tap()
        
        // Tap share button
        let shareButton = app.buttons["activity_share_button"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5.0))
        shareButton.tap()
        
        // Change Theme/Format and save to photos
        let darkThemeButton = app.buttons["share_theme_dark"]
        XCTAssertTrue(darkThemeButton.waitForExistence(timeout: 5.0))
        darkThemeButton.tap()
        
        let squareFormatButton = app.buttons["share_format_square"]
        squareFormatButton.tap()
        
        let exportButton = app.buttons["share_export_to_photos"]
        exportButton.tap()
        
        // Verify UIActivityViewController is displayed
        let activityListView = app.otherElements["ActivityListView"]
        XCTAssertTrue(activityListView.waitForExistence(timeout: 5.0))
    }
}
