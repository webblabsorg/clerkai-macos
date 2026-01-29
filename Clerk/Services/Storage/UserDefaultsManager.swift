import Foundation

/// Type-safe UserDefaults wrapper for app preferences
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {}
    
    // MARK: - Keys
    
    enum Key: String {
        // App State
        case hasCompletedOnboarding
        case lastActiveDate
        case appVersion
        
        // UI Preferences
        case appTheme
        case panelPosition
        case defaultUIState
        
        // Localization
        case preferredLanguage
        case preferredCurrency
        
        // Behavior
        case launchAtLogin
        case showInDock
        case showInMenuBar
        case playSounds
        case showSuggestionsAutomatically
        
        // Hot Keys
        case togglePanelHotKey
        case quickSummarizeHotKey
        case quickRiskCheckHotKey
        
        // Cache
        case cachedToolCategories
        case cachedRecentTools
        case lastSyncDate
    }
    
    // MARK: - Generic Accessors
    
    func set<T: Encodable>(_ value: T, for key: Key) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key.rawValue)
        }
    }
    
    func get<T: Decodable>(_ key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
    
    // MARK: - Primitive Accessors
    
    func setBool(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getBool(_ key: Key) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }
    
    func setString(_ value: String, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getString(_ key: Key) -> String? {
        defaults.string(forKey: key.rawValue)
    }
    
    func setInt(_ value: Int, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getInt(_ key: Key) -> Int {
        defaults.integer(forKey: key.rawValue)
    }
    
    func setDate(_ value: Date, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getDate(_ key: Key) -> Date? {
        defaults.object(forKey: key.rawValue) as? Date
    }
    
    // MARK: - Remove
    
    func remove(_ key: Key) {
        defaults.removeObject(forKey: key.rawValue)
    }
    
    // MARK: - Convenience Properties
    
    var hasCompletedOnboarding: Bool {
        get { getBool(.hasCompletedOnboarding) }
        set { setBool(newValue, for: .hasCompletedOnboarding) }
    }
    
    var preferredLanguage: String {
        get { getString(.preferredLanguage) ?? "en" }
        set { setString(newValue, for: .preferredLanguage) }
    }
    
    var preferredCurrency: String {
        get { getString(.preferredCurrency) ?? "USD" }
        set { setString(newValue, for: .preferredCurrency) }
    }
    
    var appTheme: AppTheme {
        get {
            guard let raw = getString(.appTheme),
                  let theme = AppTheme(rawValue: raw) else {
                return .system
            }
            return theme
        }
        set { setString(newValue.rawValue, for: .appTheme) }
    }
    
    var launchAtLogin: Bool {
        get { getBool(.launchAtLogin) }
        set { setBool(newValue, for: .launchAtLogin) }
    }
    
    var showInDock: Bool {
        get { getBool(.showInDock) }
        set { setBool(newValue, for: .showInDock) }
    }
    
    var showInMenuBar: Bool {
        get { getBool(.showInMenuBar) }
        set { setBool(newValue, for: .showInMenuBar) }
    }
}
