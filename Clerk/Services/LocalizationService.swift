import Foundation
import Combine

/// Service for handling localization and internationalization
final class LocalizationService {
    static let shared = LocalizationService()
    
    @Published private(set) var currentLanguage: Language
    @Published private(set) var currentLocale: Locale
    
    private var translations: [String: [String: Any]] = [:]
    private let defaults = UserDefaultsManager.shared
    
    private init() {
        // Load preferred language or detect from system
        let preferredCode = defaults.preferredLanguage
        currentLanguage = Language.find(byCode: preferredCode) ?? Language.allSupported.first!
        currentLocale = Locale(identifier: currentLanguage.code)
        
        loadTranslations()
    }
    
    // MARK: - Language Management
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        currentLocale = Locale(identifier: language.code)
        defaults.preferredLanguage = language.code
        
        loadTranslations()
        
        // Notify app of language change
        NotificationCenter.default.post(name: .languageDidChange, object: language)
    }
    
    func detectSystemLanguage() -> Language {
        let systemLocale = Locale.current
        let languageCode = systemLocale.language.languageCode?.identifier ?? "en"
        
        // Try exact match first
        if let language = Language.find(byCode: languageCode) {
            return language
        }
        
        // Try base language (e.g., "en" for "en-US")
        let baseCode = String(languageCode.prefix(2))
        if let language = Language.find(byCode: baseCode) {
            return language
        }
        
        // Default to English
        return Language.allSupported.first { $0.code == "en" }!
    }
    
    // MARK: - Translation Loading
    
    private func loadTranslations() {
        // Load from bundled JSON files
        let languageCode = currentLanguage.code
        
        guard let url = Bundle.main.url(forResource: languageCode, withExtension: "json", subdirectory: "Localization"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback to English
            loadFallbackTranslations()
            return
        }
        
        translations[languageCode] = json
    }
    
    private func loadFallbackTranslations() {
        guard let url = Bundle.main.url(forResource: "en", withExtension: "json", subdirectory: "Localization"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        translations["en"] = json
    }
    
    // MARK: - Translation Access
    
    func translate(_ key: String, default defaultValue: String? = nil) -> String {
        let components = key.split(separator: ".").map(String.init)
        
        guard let langTranslations = translations[currentLanguage.code] ?? translations["en"] else {
            return defaultValue ?? key
        }
        
        var current: Any = langTranslations
        for component in components {
            guard let dict = current as? [String: Any],
                  let next = dict[component] else {
                return defaultValue ?? key
            }
            current = next
        }
        
        return (current as? String) ?? defaultValue ?? key
    }
    
    func translate(_ key: String, with arguments: [String: String]) -> String {
        var result = translate(key)
        
        for (placeholder, value) in arguments {
            result = result.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }
        
        return result
    }
    
    // MARK: - RTL Support
    
    var isRTL: Bool {
        currentLanguage.isRTL
    }
    
    var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }
}

// MARK: - Layout Direction

enum LayoutDirection {
    case leftToRight
    case rightToLeft
}

// MARK: - Notifications

extension Notification.Name {
    static let languageDidChange = Notification.Name("com.clerk.languageDidChange")
}

// MARK: - String Extension for Localization

extension String {
    var localized: String {
        LocalizationService.shared.translate(self)
    }
    
    func localized(with arguments: [String: String]) -> String {
        LocalizationService.shared.translate(self, with: arguments)
    }
}
