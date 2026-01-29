import Foundation
import AppKit

/// Integration with Microsoft Word for content extraction
final class WordIntegration {
    static let shared = WordIntegration()
    
    private let accessibilityService = AccessibilityService.shared
    private let appleScript = AppleScriptRunner.shared
    
    private init() {}
    
    // MARK: - Detection
    
    var isWordRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.microsoft.Word"
        }
    }
    
    var isWordActive: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Word"
    }
    
    // MARK: - Content Extraction
    
    func getDocumentContent() -> WordDocumentContent? {
        guard isWordRunning else { return nil }
        
        let windowInfo = accessibilityService.getActiveWindowInfo()
        
        // Prefer AppleScript for selected text and document name (more reliable than AX for Word).
        let scriptSelection = """
        tell application \"Microsoft Word\"
            if not (exists active document) then return ""
            try
                return content of selection as string
            on error
                return ""
            end try
        end tell
        """
        
        let scriptDocName = """
        tell application \"Microsoft Word\"
            if not (exists active document) then return ""
            try
                return name of active document as string
            on error
                return ""
            end try
        end tell
        """
        
        var selectedText: String? = nil
        var documentName: String? = nil
        
        if isWordActive {
            if let value = try? appleScript.runString(scriptSelection), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedText = value
            }
            if let value = try? appleScript.runString(scriptDocName), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                documentName = value
            }
        }
        
        // Fallback to AX-based heuristics
        let fallbackSelected = accessibilityService.getSelectedText()
        if selectedText == nil, let fallbackSelected {
            selectedText = fallbackSelected
        }
        
        if documentName == nil {
            documentName = parseDocumentName(from: windowInfo?.title)
        }
        
        let fullText = accessibilityService.getTextContent()
        
        return WordDocumentContent(
            documentName: documentName,
            filePath: windowInfo?.documentPath,
            selectedText: selectedText,
            fullText: fullText,
            wordCount: fullText?.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count ?? 0
        )
    }
    
    private func parseDocumentName(from windowTitle: String?) -> String? {
        guard let title = windowTitle else { return nil }
        if let dashIndex = title.range(of: " - Microsoft Word")?.lowerBound {
            return String(title[..<dashIndex])
        }
        if let dashIndex = title.range(of: " — Microsoft Word")?.lowerBound {
            return String(title[..<dashIndex])
        }
        return title
    }
    
    // MARK: - Document Analysis
    
    func analyzeCurrentDocument() -> DocumentAnalysisResult? {
        guard let content = getDocumentContent() else { return nil }
        
        let analyzer = DocumentAnalyzer.shared
        let textToAnalyze = content.selectedText ?? content.fullText ?? ""
        
        guard !textToAnalyze.isEmpty else { return nil }
        
        return DocumentAnalysisResult(
            documentType: analyzer.detectDocumentType(from: textToAnalyze),
            legalTerms: analyzer.detectLegalTerms(in: textToAnalyze),
            riskIndicators: analyzer.detectRiskIndicators(in: textToAnalyze),
            entities: analyzer.extractKeyEntities(from: textToAnalyze),
            summary: analyzer.generateQuickSummary(of: textToAnalyze)
        )
    }
    
    // MARK: - Actions
    
    func insertText(_ text: String) {
        guard isWordActive else { return }
        
        // Use clipboard to insert
        ClipboardService.shared.setText(text)
        SelectionService.shared.pasteText(text)
    }
    
    func replaceSelection(with text: String) {
        guard isWordActive, accessibilityService.getSelectedText() != nil else { return }
        
        SelectionService.shared.replaceSelection(with: text)
    }
}

// MARK: - Supporting Types

struct WordDocumentContent {
    let documentName: String?
    let filePath: String?
    let selectedText: String?
    let fullText: String?
    let wordCount: Int
    
    var hasSelection: Bool {
        selectedText != nil && !selectedText!.isEmpty
    }
    
    var fileName: String? {
        guard let path = filePath else { return documentName }
        return (path as NSString).lastPathComponent
    }
}

struct DocumentAnalysisResult {
    let documentType: DocumentType
    let legalTerms: [LegalTerm]
    let riskIndicators: [RiskIndicator]
    let entities: [ExtractedEntity]
    let summary: String
    
    var hasLegalContent: Bool {
        !legalTerms.isEmpty || documentType != .unknown
    }
    
    var riskLevel: RiskLevel {
        let highCount = riskIndicators.filter { $0.severity == .high }.count
        let mediumCount = riskIndicators.filter { $0.severity == .medium }.count
        
        if highCount >= 3 { return .critical }
        if highCount >= 1 { return .high }
        if mediumCount >= 3 { return .medium }
        if mediumCount >= 1 { return .low }
        return .none
    }
}

enum RiskLevel: String {
    case none
    case low
    case medium
    case high
    case critical
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}
