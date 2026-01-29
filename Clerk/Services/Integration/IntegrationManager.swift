import Foundation
import Combine

/// Central manager for all application integrations
final class IntegrationManager {
    static let shared = IntegrationManager()
    
    // Integration services
    let word = WordIntegration.shared
    let pdf = PDFIntegration.shared
    let email = EmailIntegration.shared
    let browser = BrowserIntegration.shared
    
    // Context services
    let contextEngine = ContextEngine.shared
    let appMonitor = AppMonitorService.shared
    
    @Published private(set) var activeIntegration: ActiveIntegration = .none
    @Published private(set) var integrationContent: IntegrationContent?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        appMonitor.$activeApp
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateActiveIntegration()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Integration Detection
    
    private func updateActiveIntegration() {
        guard let bundleId = appMonitor.activeApp?.bundleIdentifier else {
            activeIntegration = .none
            integrationContent = nil
            return
        }
        
        // Determine active integration
        if bundleId == "com.microsoft.Word" {
            activeIntegration = .word
            updateWordContent()
        } else if pdf.isPDFViewerActive {
            activeIntegration = .pdf
            updatePDFContent()
        } else if email.isEmailClientActive {
            activeIntegration = .email
            updateEmailContent()
        } else if browser.isBrowserActive {
            activeIntegration = .browser
            updateBrowserContent()
        } else {
            activeIntegration = .none
            integrationContent = nil
        }
    }
    
    // MARK: - Content Updates
    
    private func updateWordContent() {
        guard let content = word.getDocumentContent() else {
            integrationContent = nil
            return
        }
        
        let analysis = word.analyzeCurrentDocument()
        
        integrationContent = IntegrationContent(
            type: .word,
            title: content.documentName,
            selectedText: content.selectedText,
            fullText: content.fullText,
            documentType: analysis?.documentType,
            legalTerms: analysis?.legalTerms ?? [],
            riskIndicators: analysis?.riskIndicators ?? [],
            suggestedTools: getSuggestedTools(for: .word, analysis: analysis)
        )
    }
    
    private func updatePDFContent() {
        let analysis = pdf.analyzeCurrentPDF()
        let selectedText = pdf.getSelectedText()
        
        integrationContent = IntegrationContent(
            type: .pdf,
            title: appMonitor.activeWindow?.title,
            selectedText: selectedText,
            fullText: nil,
            documentType: analysis?.documentType,
            legalTerms: analysis?.legalTerms ?? [],
            riskIndicators: analysis?.riskIndicators ?? [],
            suggestedTools: getSuggestedTools(for: .pdf, analysis: nil)
        )
    }
    
    private func updateEmailContent() {
        guard let content = email.getEmailContent() else {
            integrationContent = nil
            return
        }
        
        let analysis = email.analyzeCurrentEmail()
        
        integrationContent = IntegrationContent(
            type: .email,
            title: content.subject,
            selectedText: content.selectedText,
            fullText: content.bodyText,
            documentType: .email,
            legalTerms: analysis?.legalTerms ?? [],
            riskIndicators: [],
            suggestedTools: analysis?.suggestedActions ?? []
        )
    }
    
    private func updateBrowserContent() {
        guard let content = browser.getBrowserContent() else {
            integrationContent = nil
            return
        }
        
        let analysis = browser.analyzeCurrentPage()
        
        integrationContent = IntegrationContent(
            type: .browser,
            title: content.title,
            selectedText: content.selectedText,
            fullText: nil,
            documentType: nil,
            legalTerms: analysis?.legalTerms ?? [],
            riskIndicators: [],
            suggestedTools: analysis?.suggestedTools ?? []
        )
    }
    
    // MARK: - Tool Suggestions
    
    private func getSuggestedTools(for integration: ActiveIntegration, analysis: DocumentAnalysisResult?) -> [String] {
        var tools: [String] = []
        
        // Based on document type
        if let docType = analysis?.documentType {
            tools.append(contentsOf: docType.suggestedTools.prefix(2))
        }
        
        // Based on risk indicators
        if let risks = analysis?.riskIndicators, !risks.isEmpty {
            tools.insert("contract_risk_analyzer", at: 0)
        }
        
        // Integration-specific defaults
        switch integration {
        case .word:
            if tools.isEmpty {
                tools = ["document_summarizer", "contract_risk_analyzer", "legal_email_drafter"]
            }
        case .pdf:
            if tools.isEmpty {
                tools = ["document_summarizer", "contract_risk_analyzer", "clause_extractor"]
            }
        case .email:
            if tools.isEmpty {
                tools = ["legal_email_drafter", "email_response_generator", "tone_analyzer"]
            }
        case .browser:
            if tools.isEmpty {
                tools = ["legal_research_assistant", "case_law_finder", "document_summarizer"]
            }
        case .none:
            tools = ["document_summarizer", "legal_research_assistant"]
        }
        
        return Array(Set(tools)).prefix(4).map { $0 }
    }
    
    // MARK: - Actions
    
    func insertText(_ text: String) {
        switch activeIntegration {
        case .word:
            word.insertText(text)
        case .email:
            email.insertText(text)
        case .browser, .pdf, .none:
            // Use clipboard
            ClipboardService.shared.setText(text)
        }
    }
    
    func replaceSelection(with text: String) {
        switch activeIntegration {
        case .word:
            word.replaceSelection(with: text)
        default:
            SelectionService.shared.replaceSelection(with: text)
        }
    }
    
    // MARK: - Refresh
    
    func refreshContent() {
        updateActiveIntegration()
    }
}

// MARK: - Supporting Types

enum ActiveIntegration: String {
    case word
    case pdf
    case email
    case browser
    case none
    
    var displayName: String {
        switch self {
        case .word: return "Microsoft Word"
        case .pdf: return "PDF Viewer"
        case .email: return "Email"
        case .browser: return "Browser"
        case .none: return "None"
        }
    }
    
    var icon: String {
        switch self {
        case .word: return "doc.text"
        case .pdf: return "doc.fill"
        case .email: return "envelope"
        case .browser: return "globe"
        case .none: return "questionmark.circle"
        }
    }
}

struct IntegrationContent {
    let type: ActiveIntegration
    let title: String?
    let selectedText: String?
    let fullText: String?
    let documentType: DocumentType?
    let legalTerms: [LegalTerm]
    let riskIndicators: [RiskIndicator]
    let suggestedTools: [String]
    
    var hasSelection: Bool {
        selectedText != nil && !selectedText!.isEmpty
    }
    
    var hasLegalContent: Bool {
        !legalTerms.isEmpty || (documentType != nil && documentType != .unknown)
    }
    
    var textForAnalysis: String? {
        selectedText ?? fullText
    }
}
