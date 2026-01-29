import Foundation
import AppKit

/// Integration with web browsers for content extraction
final class BrowserIntegration {
    static let shared = BrowserIntegration()
    
    private let accessibilityService = AccessibilityService.shared
    
    private let supportedBrowsers: [String: Browser] = [
        "com.apple.Safari": .safari,
        "com.google.Chrome": .chrome,
        "org.mozilla.firefox": .firefox,
        "com.microsoft.edgemac": .edge,
        "com.brave.Browser": .brave,
        "company.thebrowser.Browser": .arc
    ]
    
    private init() {}
    
    // MARK: - Detection
    
    var isBrowserActive: Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return supportedBrowsers.keys.contains(bundleId)
    }
    
    var activeBrowser: Browser? {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return nil
        }
        return supportedBrowsers[bundleId]
    }
    
    // MARK: - Content Extraction
    
    func getBrowserContent() -> BrowserContent? {
        guard isBrowserActive else { return nil }
        
        let windowInfo = accessibilityService.getActiveWindowInfo()
        let selectedText = accessibilityService.getSelectedText()
        
        // Parse URL and title from window
        let (url, title) = parseWindowTitle(windowInfo?.title)
        
        // Detect page type
        let pageType = detectPageType(url: url, title: title)
        
        return BrowserContent(
            browser: activeBrowser ?? .unknown,
            url: url,
            title: title,
            pageType: pageType,
            selectedText: selectedText,
            timestamp: Date()
        )
    }
    
    private func parseWindowTitle(_ title: String?) -> (url: String?, title: String?) {
        guard let title = title else { return (nil, nil) }
        
        // Different browsers format titles differently
        // Safari: "Page Title"
        // Chrome: "Page Title - Google Chrome"
        // Firefox: "Page Title — Mozilla Firefox"
        
        var pageTitle = title
        
        // Remove browser suffix
        let suffixes = [
            " - Google Chrome",
            " — Mozilla Firefox",
            " - Microsoft Edge",
            " - Brave",
            " - Arc"
        ]
        
        for suffix in suffixes {
            if let range = title.range(of: suffix) {
                pageTitle = String(title[..<range.lowerBound])
                break
            }
        }
        
        // Try to extract URL if present in title (some pages show URL)
        var url: String?
        if pageTitle.hasPrefix("http://") || pageTitle.hasPrefix("https://") {
            url = pageTitle
        }
        
        return (url, pageTitle)
    }
    
    private func detectPageType(url: String?, title: String?) -> BrowserPageType {
        let combined = ((url ?? "") + " " + (title ?? "")).lowercased()
        
        // Legal research sites
        let legalResearchSites = [
            "westlaw", "lexisnexis", "casetext", "fastcase",
            "google scholar", "justia", "findlaw", "law.cornell"
        ]
        
        for site in legalResearchSites {
            if combined.contains(site) {
                return .legalResearch
            }
        }
        
        // Government/court sites
        let govSites = ["uscourts.gov", "supremecourt.gov", ".gov/", "pacer"]
        for site in govSites {
            if combined.contains(site) {
                return .courtWebsite
            }
        }
        
        // Document sites
        let docSites = ["docs.google.com", "drive.google.com", "dropbox", "onedrive"]
        for site in docSites {
            if combined.contains(site) {
                return .documentSite
            }
        }
        
        // Email webmail
        let emailSites = ["mail.google.com", "outlook.live.com", "mail.yahoo.com"]
        for site in emailSites {
            if combined.contains(site) {
                return .webmail
            }
        }
        
        // News/articles
        let newsSites = ["news", "article", "blog", "post"]
        for keyword in newsSites {
            if combined.contains(keyword) {
                return .newsArticle
            }
        }
        
        return .general
    }
    
    // MARK: - Browser Analysis
    
    func analyzeCurrentPage() -> BrowserAnalysisResult? {
        guard let content = getBrowserContent() else { return nil }
        
        let textToAnalyze = content.selectedText ?? ""
        guard !textToAnalyze.isEmpty else {
            // Return basic analysis without text
            return BrowserAnalysisResult(
                pageType: content.pageType,
                legalTerms: [],
                suggestedTools: getSuggestedTools(for: content.pageType),
                hasSelection: false
            )
        }
        
        let analyzer = DocumentAnalyzer.shared
        
        return BrowserAnalysisResult(
            pageType: content.pageType,
            legalTerms: analyzer.detectLegalTerms(in: textToAnalyze),
            suggestedTools: getSuggestedTools(for: content.pageType),
            hasSelection: true
        )
    }
    
    private func getSuggestedTools(for pageType: BrowserPageType) -> [String] {
        switch pageType {
        case .legalResearch:
            return ["case_law_finder", "citation_validator", "legal_research_assistant"]
        case .courtWebsite:
            return ["case_law_finder", "document_summarizer", "citation_validator"]
        case .documentSite:
            return ["document_summarizer", "contract_risk_analyzer"]
        case .webmail:
            return ["legal_email_drafter", "email_response_generator"]
        case .newsArticle:
            return ["document_summarizer", "legal_research_assistant"]
        case .general:
            return ["document_summarizer", "legal_research_assistant"]
        }
    }
    
    // MARK: - URL Handling
    
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
    
    func openLegalResearch(query: String) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Open Google Scholar by default
        let url = "https://scholar.google.com/scholar?q=\(encodedQuery)"
        openURL(url)
    }
    
    func openCaseLaw(citation: String) {
        let encodedCitation = citation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? citation
        
        // Open Google Scholar case search
        let url = "https://scholar.google.com/scholar?q=\(encodedCitation)"
        openURL(url)
    }
}

// MARK: - Supporting Types

enum Browser: String {
    case safari
    case chrome
    case firefox
    case edge
    case brave
    case arc
    case unknown
}

enum BrowserPageType {
    case legalResearch
    case courtWebsite
    case documentSite
    case webmail
    case newsArticle
    case general
}

struct BrowserContent {
    let browser: Browser
    let url: String?
    let title: String?
    let pageType: BrowserPageType
    let selectedText: String?
    let timestamp: Date
    
    var hasSelection: Bool {
        selectedText != nil && !selectedText!.isEmpty
    }
}

struct BrowserAnalysisResult {
    let pageType: BrowserPageType
    let legalTerms: [LegalTerm]
    let suggestedTools: [String]
    let hasSelection: Bool
}
