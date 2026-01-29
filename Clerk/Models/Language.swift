import Foundation

struct Language: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let code: String
    let name: String
    let nativeName: String
    let isRTL: Bool
    
    static let allSupported: [Language] = [
        // Europe
        Language(id: "en", code: "en", name: "English", nativeName: "English", isRTL: false),
        Language(id: "es", code: "es", name: "Spanish", nativeName: "Español", isRTL: false),
        Language(id: "fr", code: "fr", name: "French", nativeName: "Français", isRTL: false),
        Language(id: "de", code: "de", name: "German", nativeName: "Deutsch", isRTL: false),
        Language(id: "it", code: "it", name: "Italian", nativeName: "Italiano", isRTL: false),
        Language(id: "pt", code: "pt", name: "Portuguese", nativeName: "Português", isRTL: false),
        Language(id: "nl", code: "nl", name: "Dutch", nativeName: "Nederlands", isRTL: false),
        Language(id: "pl", code: "pl", name: "Polish", nativeName: "Polski", isRTL: false),
        Language(id: "sv", code: "sv", name: "Swedish", nativeName: "Svenska", isRTL: false),
        Language(id: "no", code: "no", name: "Norwegian", nativeName: "Norsk", isRTL: false),
        Language(id: "da", code: "da", name: "Danish", nativeName: "Dansk", isRTL: false),
        Language(id: "fi", code: "fi", name: "Finnish", nativeName: "Suomi", isRTL: false),
        Language(id: "el", code: "el", name: "Greek", nativeName: "Ελληνικά", isRTL: false),
        Language(id: "cs", code: "cs", name: "Czech", nativeName: "Čeština", isRTL: false),
        Language(id: "ro", code: "ro", name: "Romanian", nativeName: "Română", isRTL: false),
        Language(id: "hu", code: "hu", name: "Hungarian", nativeName: "Magyar", isRTL: false),
        Language(id: "uk", code: "uk", name: "Ukrainian", nativeName: "Українська", isRTL: false),
        Language(id: "ru", code: "ru", name: "Russian", nativeName: "Русский", isRTL: false),
        
        // Asia
        Language(id: "zh-CN", code: "zh-CN", name: "Chinese (Simplified)", nativeName: "简体中文", isRTL: false),
        Language(id: "zh-TW", code: "zh-TW", name: "Chinese (Traditional)", nativeName: "繁體中文", isRTL: false),
        Language(id: "ja", code: "ja", name: "Japanese", nativeName: "日本語", isRTL: false),
        Language(id: "ko", code: "ko", name: "Korean", nativeName: "한국어", isRTL: false),
        Language(id: "hi", code: "hi", name: "Hindi", nativeName: "हिन्दी", isRTL: false),
        Language(id: "th", code: "th", name: "Thai", nativeName: "ไทย", isRTL: false),
        Language(id: "vi", code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", isRTL: false),
        Language(id: "id", code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", isRTL: false),
        Language(id: "ms", code: "ms", name: "Malay", nativeName: "Bahasa Melayu", isRTL: false),
        Language(id: "fil", code: "fil", name: "Filipino", nativeName: "Filipino", isRTL: false),
        Language(id: "bn", code: "bn", name: "Bengali", nativeName: "বাংলা", isRTL: false),
        Language(id: "ta", code: "ta", name: "Tamil", nativeName: "தமிழ்", isRTL: false),
        
        // Middle East (RTL)
        Language(id: "ar", code: "ar", name: "Arabic", nativeName: "العربية", isRTL: true),
        Language(id: "he", code: "he", name: "Hebrew", nativeName: "עברית", isRTL: true),
        Language(id: "tr", code: "tr", name: "Turkish", nativeName: "Türkçe", isRTL: false),
        Language(id: "fa", code: "fa", name: "Persian", nativeName: "فارسی", isRTL: true),
        Language(id: "ur", code: "ur", name: "Urdu", nativeName: "اردو", isRTL: true),
        
        // Americas
        Language(id: "es-419", code: "es-419", name: "Spanish (Latin America)", nativeName: "Español (Latinoamérica)", isRTL: false),
        Language(id: "pt-BR", code: "pt-BR", name: "Portuguese (Brazil)", nativeName: "Português (Brasil)", isRTL: false),
        Language(id: "fr-CA", code: "fr-CA", name: "French (Canada)", nativeName: "Français (Canada)", isRTL: false),
        
        // Africa
        Language(id: "sw", code: "sw", name: "Swahili", nativeName: "Kiswahili", isRTL: false),
        Language(id: "af", code: "af", name: "Afrikaans", nativeName: "Afrikaans", isRTL: false),
        Language(id: "am", code: "am", name: "Amharic", nativeName: "አማርኛ", isRTL: false),
    ]
    
    static func find(byCode code: String) -> Language? {
        allSupported.first { $0.code == code }
    }
}
