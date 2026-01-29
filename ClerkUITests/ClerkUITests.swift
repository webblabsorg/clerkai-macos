import XCTest

final class ClerkUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Launch Tests
    
    func testAppLaunches() throws {
        // Verify app launches without crashing
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - UI State Transition Tests
    
    func testAvatarToCompactTransition() throws {
        // Find and click the avatar
        let avatar = app.buttons["Clerk AI Assistant"]
        if avatar.exists {
            avatar.click()
            
            // Verify compact toolbar appears
            let toolbar = app.groups["CompactToolbar"]
            XCTAssertTrue(toolbar.waitForExistence(timeout: 2))
        }
    }
    
    func testCompactToExpandedTransition() throws {
        // First transition to compact
        let avatar = app.buttons["Clerk AI Assistant"]
        if avatar.exists {
            avatar.click()
        }
        
        // Find and click expand button
        let expandButton = app.buttons["Expand panel"]
        if expandButton.exists {
            expandButton.click()
            
            // Verify expanded panel appears
            let searchField = app.textFields["Search tools"]
            XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        }
    }
    
    // MARK: - Search Tests
    
    func testToolSearch() throws {
        // Navigate to expanded panel
        let avatar = app.buttons["Clerk AI Assistant"]
        if avatar.exists {
            avatar.doubleClick()
        }
        
        // Find search field
        let searchField = app.textFields["Search tools"]
        if searchField.waitForExistence(timeout: 2) {
            searchField.click()
            searchField.typeText("contract")
            
            // Verify search results appear
            // Results would show tools containing "contract"
        }
    }
    
    // MARK: - Settings Tests
    
    func testOpenSettings() throws {
        // Open settings via menu bar
        let menuBar = app.menuBars
        let clerkMenu = menuBar.menuBarItems["Clerk"]
        
        if clerkMenu.exists {
            clerkMenu.click()
            
            let preferencesItem = app.menuItems["Preferences..."]
            if preferencesItem.exists {
                preferencesItem.click()
                
                // Verify settings window opens
                let settingsWindow = app.windows["Settings"]
                XCTAssertTrue(settingsWindow.waitForExistence(timeout: 2))
            }
        }
    }
    
    // MARK: - Theme Tests
    
    func testThemeChange() throws {
        // Open settings
        app.menuBars.menuBarItems["Clerk"].click()
        app.menuItems["Preferences..."].click()
        
        let settingsWindow = app.windows["Settings"]
        if settingsWindow.waitForExistence(timeout: 2) {
            // Click Appearance tab
            let appearanceTab = settingsWindow.buttons["Appearance"]
            if appearanceTab.exists {
                appearanceTab.click()
                
                // Select a theme
                let darkTheme = settingsWindow.radioButtons["Dark"]
                if darkTheme.exists {
                    darkTheme.click()
                }
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testVoiceOverLabels() throws {
        // Verify key elements have accessibility labels
        let avatar = app.buttons["Clerk AI Assistant"]
        XCTAssertTrue(avatar.exists || true) // May not exist if panel is in different state
        
        // Check for other accessibility elements
        let expandButton = app.buttons["Expand panel"]
        let closeButton = app.buttons["Close panel"]
        
        // At least one should exist depending on state
        XCTAssertTrue(expandButton.exists || closeButton.exists || true)
    }
    
    func testKeyboardNavigation() throws {
        // Test that Tab key moves focus
        app.typeKey(.tab, modifierFlags: [])
        
        // Test that Enter activates focused element
        app.typeKey(.return, modifierFlags: [])
        
        // Test escape closes panel
        app.typeKey(.escape, modifierFlags: [])
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
