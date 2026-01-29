import Foundation
import AppKit
import PDFKit

/// Integration with PDF viewers for content extraction
final class PDFIntegration {
    static let shared = PDFIntegration()
    
    private let accessibilityService = AccessibilityService.shared
    
    private let supportedApps = [
        "com.apple.Preview",
        "com.adobe.Acrobat.Pro",
        "com.adobe.Reader",
        "com.readdle.PDFExpert-Mac"
    ]
    
    private init() {}
    
    // MARK: - Detection
    
    var isPDFViewerActive: Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return supportedApps.contains(bundleId)
    }
    
    func isPDFFile(at path: String) -> Bool {
        path.lowercased().hasSuffix(".pdf")
    }
    
    // MARK: - Content Extraction via Accessibility
    
    func getSelectedText() -> String? {
        guard isPDFViewerActive else { return nil }
        return accessibilityService.getSelectedText()
    }
    
    func getVisibleText() -> String? {
        guard isPDFViewerActive else { return nil }
        return accessibilityService.getTextContent()
    }
    
    // MARK: - Direct PDF Extraction
    
    func extractText(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        
        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText
    }
    
    func extractText(from url: URL, pages: Range<Int>) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        
        var fullText = ""
        for pageIndex in pages {
            guard pageIndex < document.pageCount else { continue }
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText
    }
    
    // MARK: - PDF Metadata
    
    func getMetadata(from url: URL) -> PDFMetadata? {
        guard let document = PDFDocument(url: url) else { return nil }
        
        let attributes = document.documentAttributes ?? [:]
        
        return PDFMetadata(
            title: attributes[PDFDocumentAttribute.titleAttribute] as? String,
            author: attributes[PDFDocumentAttribute.authorAttribute] as? String,
            subject: attributes[PDFDocumentAttribute.subjectAttribute] as? String,
            creator: attributes[PDFDocumentAttribute.creatorAttribute] as? String,
            creationDate: attributes[PDFDocumentAttribute.creationDateAttribute] as? Date,
            modificationDate: attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date,
            pageCount: document.pageCount
        )
    }
    
    // MARK: - PDF Analysis
    
    func analyzePDF(at url: URL) -> PDFAnalysisResult? {
        guard let text = extractText(from: url) else { return nil }
        
        let analyzer = DocumentAnalyzer.shared
        let metadata = getMetadata(from: url)
        
        return PDFAnalysisResult(
            metadata: metadata,
            documentType: analyzer.detectDocumentType(from: text),
            legalTerms: analyzer.detectLegalTerms(in: text),
            riskIndicators: analyzer.detectRiskIndicators(in: text),
            wordCount: text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
            summary: analyzer.generateQuickSummary(of: text, maxSentences: 5)
        )
    }
    
    func analyzeCurrentPDF() -> PDFAnalysisResult? {
        guard isPDFViewerActive else { return nil }
        
        // Try to get file path from window
        if let windowInfo = accessibilityService.getActiveWindowInfo(),
           let path = windowInfo.documentPath,
           isPDFFile(at: path) {
            return analyzePDF(at: URL(fileURLWithPath: path))
        }
        
        // Fall back to selected/visible text
        let text = getSelectedText() ?? getVisibleText() ?? ""
        guard !text.isEmpty else { return nil }
        
        let analyzer = DocumentAnalyzer.shared
        
        return PDFAnalysisResult(
            metadata: nil,
            documentType: analyzer.detectDocumentType(from: text),
            legalTerms: analyzer.detectLegalTerms(in: text),
            riskIndicators: analyzer.detectRiskIndicators(in: text),
            wordCount: text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
            summary: analyzer.generateQuickSummary(of: text)
        )
    }
    
    // MARK: - Page Extraction
    
    func extractPage(from url: URL, pageNumber: Int) -> PDFPageContent? {
        guard let document = PDFDocument(url: url),
              pageNumber < document.pageCount,
              let page = document.page(at: pageNumber) else {
            return nil
        }
        
        return PDFPageContent(
            pageNumber: pageNumber,
            text: page.string,
            bounds: page.bounds(for: .mediaBox)
        )
    }
}

// MARK: - Supporting Types

struct PDFMetadata {
    let title: String?
    let author: String?
    let subject: String?
    let creator: String?
    let creationDate: Date?
    let modificationDate: Date?
    let pageCount: Int
}

struct PDFAnalysisResult {
    let metadata: PDFMetadata?
    let documentType: DocumentType
    let legalTerms: [LegalTerm]
    let riskIndicators: [RiskIndicator]
    let wordCount: Int
    let summary: String
    
    var pageCount: Int {
        metadata?.pageCount ?? 0
    }
    
    var hasLegalContent: Bool {
        !legalTerms.isEmpty || documentType != .unknown
    }
}

struct PDFPageContent {
    let pageNumber: Int
    let text: String?
    let bounds: CGRect
}
