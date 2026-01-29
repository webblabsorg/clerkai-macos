import Foundation

struct DetectedContext: Codable, Equatable {
    let sourceApp: SourceApp
    let documentType: DocumentType?
    let selectedText: String?
    let windowTitle: String?
    let filePath: String?
    let detectedAt: Date
    
    var hasContent: Bool {
        selectedText != nil || filePath != nil
    }
}

enum SourceApp: String, Codable, CaseIterable {
    case microsoftWord = "com.microsoft.Word"
    case googleDocs = "com.google.docs.web" // Web-based - use unique identifier
    case pages = "com.apple.iWork.Pages"
    case preview = "com.apple.Preview"
    case adobeAcrobat = "com.adobe.Acrobat.Pro"
    case mail = "com.apple.mail"
    case outlook = "com.microsoft.Outlook"
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case firefox = "org.mozilla.firefox"
    case excel = "com.microsoft.Excel"
    case numbers = "com.apple.iWork.Numbers"
    case powerpoint = "com.microsoft.Powerpoint"
    case keynote = "com.apple.iWork.Keynote"
    case finder = "com.apple.finder"
    case notes = "com.apple.Notes"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .microsoftWord: return "Microsoft Word"
        case .googleDocs: return "Google Docs"
        case .pages: return "Pages"
        case .preview: return "Preview"
        case .adobeAcrobat: return "Adobe Acrobat"
        case .mail: return "Mail"
        case .outlook: return "Outlook"
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .excel: return "Excel"
        case .numbers: return "Numbers"
        case .powerpoint: return "PowerPoint"
        case .keynote: return "Keynote"
        case .finder: return "Finder"
        case .notes: return "Notes"
        case .unknown: return "Unknown"
        }
    }
    
    var suggestedCategories: [ToolCategory] {
        switch self {
        case .microsoftWord, .pages, .googleDocs:
            return [.documentDrafting, .contractReview, .legalResearch]
        case .preview, .adobeAcrobat:
            return [.contractReview, .documentDrafting, .litigationSupport]
        case .mail, .outlook:
            return [.clientCommunication, .documentDrafting]
        case .safari, .chrome, .firefox:
            return [.legalResearch, .compliance]
        case .excel, .numbers:
            return [.practiceManagement, .taxLaw]
        case .powerpoint, .keynote:
            return [.litigationSupport, .clientCommunication]
        default:
            return [.documentDrafting, .legalResearch]
        }
    }
}

enum DocumentType: String, Codable {
    case contract
    case brief
    case motion
    case pleading
    case memo
    case letter
    case email
    case spreadsheet
    case presentation
    case pdf
    case unknown
    
    var suggestedTools: [String] {
        switch self {
        case .contract:
            return ["contract_risk_analyzer", "contract_summarizer", "clause_extractor"]
        case .brief, .motion, .pleading:
            return ["legal_brief_analyzer", "citation_validator", "argument_strengthener"]
        case .memo:
            return ["memo_summarizer", "legal_research_assistant"]
        case .letter, .email:
            return ["legal_email_drafter", "tone_analyzer", "response_generator"]
        case .spreadsheet:
            return ["billing_analyzer", "time_entry_validator"]
        case .presentation:
            return ["presentation_summarizer", "key_points_extractor"]
        case .pdf:
            return ["document_summarizer", "contract_risk_analyzer", "ocr_extractor"]
        case .unknown:
            return ["document_summarizer", "legal_research_assistant"]
        }
    }
}
