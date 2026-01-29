import Foundation

/// Safari App Extension Handler stub
/// 
/// Safari extensions require a separate target in Xcode:
/// 1. File > New > Target > Safari Extension
/// 2. This creates a SafariExtensionHandler class that inherits from SFSafariExtensionHandler
/// 
/// This file provides the protocol and stub implementation for the main app side.
/// The actual extension code lives in a separate target.

// MARK: - Safari Extension Communication Protocol

/// Protocol for Safari extension to communicate with main app
protocol SafariExtensionBridge {
    func getContext(for url: URL) async -> BrowserContextData
    func getPageContent(for url: URL, content: String, selection: String?) async -> PageContentData
    func executeAction(_ action: BrowserAction) async -> ActionResultData
}

/// Main app implementation of Safari extension bridge
/// Uses XPC or App Groups for inter-process communication
final class SafariExtensionBridgeImpl: SafariExtensionBridge {
    
    static let shared = SafariExtensionBridgeImpl()
    
    private let contextEngine = ContextEngine.shared
    private let documentAnalyzer = DocumentAnalyzer.shared
    
    private init() {}
    
    func getContext(for url: URL) async -> BrowserContextData {
        let pageType = detectPageType(url: url)
        let suggestedTools = getSuggestedTools(for: pageType)
        
        return BrowserContextData(
            url: url.absoluteString,
            title: "",
            domain: url.host ?? "",
            pageType: pageType,
            hasSelection: false,
            suggestedTools: suggestedTools
        )
    }
    
    func getPageContent(for url: URL, content: String, selection: String?) async -> PageContentData {
        // Analyze content for legal relevance
        let docType = documentAnalyzer.detectDocumentType(from: content)
        let legalTerms = documentAnalyzer.detectLegalTerms(in: content)
        
        var metadata: [String: String] = [
            "documentType": docType.rawValue,
            "legalTermCount": String(legalTerms.count)
        ]
        
        if !legalTerms.isEmpty {
            metadata["topTerms"] = legalTerms.prefix(5).map { $0.term }.joined(separator: ", ")
        }
        
        return PageContentData(
            url: url.absoluteString,
            title: "",
            textContent: content,
            selectedText: selection,
            metadata: metadata
        )
    }
    
    func executeAction(_ action: BrowserAction) async -> ActionResultData {
        switch action {
        case .insertText(let text):
            await MainActor.run {
                SelectionService.shared.pasteText(text)
            }
            return ActionResultData(actionId: UUID().uuidString, success: true, message: nil)
            
        case .copyToClipboard(let text):
            await MainActor.run {
                ClipboardService.shared.setText(text)
            }
            return ActionResultData(actionId: UUID().uuidString, success: true, message: nil)
            
        case .openUrl(let urlString):
            if let url = URL(string: urlString) {
                await MainActor.run {
                    NSWorkspace.shared.open(url)
                }
                return ActionResultData(actionId: UUID().uuidString, success: true, message: nil)
            }
            return ActionResultData(actionId: UUID().uuidString, success: false, message: "Invalid URL")
            
        case .highlightText:
            return ActionResultData(actionId: UUID().uuidString, success: false, message: "Not supported")
        }
    }
    
    // MARK: - Helpers
    
    private func detectPageType(url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        // Legal research sites
        let legalResearchDomains = ["westlaw.com", "lexisnexis.com", "casetext.com", "fastcase.com", "scholar.google.com"]
        if legalResearchDomains.contains(where: { host.contains($0) }) {
            return "legalResearch"
        }
        
        // Court websites
        if host.contains(".gov") || host.contains("uscourts") || host.contains("supremecourt") {
            return "courtWebsite"
        }
        
        // Document sites
        if host.contains("docs.google.com") || host.contains("dropbox.com") || host.contains("onedrive") {
            return "documentSite"
        }
        
        // Webmail
        if host.contains("mail.google.com") || host.contains("outlook.live.com") || host.contains("outlook.office") {
            return "webmail"
        }
        
        return "general"
    }
    
    private func getSuggestedTools(for pageType: String) -> [String] {
        switch pageType {
        case "legalResearch":
            return ["case_law_finder", "citation_validator", "legal_research_assistant"]
        case "courtWebsite":
            return ["case_law_finder", "document_summarizer"]
        case "documentSite":
            return ["document_summarizer", "contract_risk_analyzer"]
        case "webmail":
            return ["legal_email_drafter", "email_response_generator"]
        default:
            return ["document_summarizer"]
        }
    }
}

// MARK: - App Group Communication

/// Shared container for Safari extension communication
/// Requires App Groups entitlement: group.com.clerk.legal
struct SafariExtensionSharedData {
    
    static let appGroupIdentifier = "group.com.clerk.legal"
    
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    static var sharedUserDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Shared State
    
    static func setCurrentContext(_ context: BrowserContextData) {
        guard let defaults = sharedUserDefaults,
              let data = try? JSONEncoder().encode(context) else { return }
        defaults.set(data, forKey: "currentBrowserContext")
    }
    
    static func getCurrentContext() -> BrowserContextData? {
        guard let defaults = sharedUserDefaults,
              let data = defaults.data(forKey: "currentBrowserContext") else { return nil }
        return try? JSONDecoder().decode(BrowserContextData.self, from: data)
    }
    
    static func setPendingAction(_ action: BrowserAction) {
        guard let defaults = sharedUserDefaults,
              let data = try? JSONEncoder().encode(action) else { return }
        defaults.set(data, forKey: "pendingBrowserAction")
    }
    
    static func getPendingAction() -> BrowserAction? {
        guard let defaults = sharedUserDefaults,
              let data = defaults.data(forKey: "pendingBrowserAction") else { return nil }
        defaults.removeObject(forKey: "pendingBrowserAction")
        return try? JSONDecoder().decode(BrowserAction.self, from: data)
    }
}
