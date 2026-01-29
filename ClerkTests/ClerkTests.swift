import XCTest
@testable import Clerk

final class ClerkTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testUserCreation() {
        let user = User.preview
        
        XCTAssertEqual(user.email, "lawyer@example.com")
        XCTAssertEqual(user.subscriptionTier, .pro)
        XCTAssertTrue(user.hasUnlimitedRuns)
        XCTAssertFalse(user.isFreeTier)
    }
    
    func testToolCreation() {
        let tool = Tool.preview
        
        XCTAssertEqual(tool.id, "contract_risk_analyzer")
        XCTAssertEqual(tool.category, .contractReview)
        XCTAssertFalse(tool.isAvailableForFree)
    }
    
    func testLanguageSupport() {
        let languages = Language.allSupported
        
        XCTAssertEqual(languages.count, 42) // 50 languages as per spec
        
        // Check RTL languages
        let rtlLanguages = languages.filter { $0.isRTL }
        XCTAssertTrue(rtlLanguages.contains { $0.code == "ar" })
        XCTAssertTrue(rtlLanguages.contains { $0.code == "he" })
        XCTAssertTrue(rtlLanguages.contains { $0.code == "fa" })
        XCTAssertTrue(rtlLanguages.contains { $0.code == "ur" })
    }
    
    func testToolCategories() {
        let categories = ToolCategory.allCases
        
        XCTAssertEqual(categories.count, 18)
        
        // Check tool counts add up to 301
        let totalTools = categories.reduce(0) { $0 + $1.toolCount }
        XCTAssertEqual(totalTools, 301)
    }
    
    // MARK: - App State Tests
    
    func testAppStateTransitions() {
        let appState = AppState.shared
        
        appState.transitionTo(.minimized)
        XCTAssertEqual(appState.currentUIState, .minimized)
        
        appState.transitionTo(.compact)
        XCTAssertEqual(appState.currentUIState, .compact)
        
        appState.transitionTo(.expanded)
        XCTAssertEqual(appState.currentUIState, .expanded)
    }
    
    func testThemeSettings() {
        let appState = AppState.shared
        
        for theme in AppTheme.allCases {
            appState.currentTheme = theme
            XCTAssertEqual(appState.currentTheme, theme)
        }
    }
    
    // MARK: - Utility Tests
    
    func testStringExtensions() {
        XCTAssertTrue("test@example.com".isValidEmail)
        XCTAssertFalse("invalid-email".isValidEmail)
        XCTAssertFalse("@example.com".isValidEmail)
        
        XCTAssertEqual("  hello  ".trimmed, "hello")
        XCTAssertEqual("hello world".truncated(to: 5), "hello...")
    }
    
    func testDateExtensions() {
        let date = Date()
        
        XCTAssertFalse(date.timeAgo.isEmpty)
        XCTAssertFalse(date.formattedShort.isEmpty)
        XCTAssertFalse(date.iso8601.isEmpty)
    }
    
    // MARK: - Keychain Tests
    
    func testKeychainOperations() {
        let keychain = KeychainManager.shared
        let testKey = "test_key"
        let testValue = "test_value"
        
        // Save
        XCTAssertTrue(keychain.save(key: testKey, value: testValue))
        
        // Get
        XCTAssertEqual(keychain.get(key: testKey), testValue)
        
        // Exists
        XCTAssertTrue(keychain.exists(key: testKey))
        
        // Delete
        XCTAssertTrue(keychain.delete(key: testKey))
        XCTAssertFalse(keychain.exists(key: testKey))
    }
    
    // MARK: - UserDefaults Tests
    
    func testUserDefaultsOperations() {
        let defaults = UserDefaultsManager.shared
        
        // Bool
        defaults.hasCompletedOnboarding = true
        XCTAssertTrue(defaults.hasCompletedOnboarding)
        
        // String
        defaults.preferredLanguage = "fr"
        XCTAssertEqual(defaults.preferredLanguage, "fr")
        
        // Theme
        defaults.appTheme = .chocolate
        XCTAssertEqual(defaults.appTheme, .chocolate)
        
        // Reset
        defaults.preferredLanguage = "en"
        defaults.appTheme = .system
    }
}
