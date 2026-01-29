import Foundation
import AppKit
import Combine

/// Service for monitoring clipboard changes
final class ClipboardService {
    static let shared = ClipboardService()
    
    @Published private(set) var currentContent: ClipboardContent?
    @Published private(set) var history: [ClipboardContent] = []
    
    private var pollTimer: Timer?
    private var lastChangeCount: Int = 0
    private let maxHistoryCount = 20
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Get content
        if let content = getClipboardContent() {
            currentContent = content
            addToHistory(content)
        }
    }
    
    // MARK: - Content Access
    
    func getClipboardContent() -> ClipboardContent? {
        let pasteboard = NSPasteboard.general
        
        // Check for text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardContent(
                type: .text,
                text: text,
                data: nil,
                timestamp: Date()
            )
        }
        
        // Check for RTF
        if let rtfData = pasteboard.data(forType: .rtf) {
            let text = String(data: rtfData, encoding: .utf8)
            return ClipboardContent(
                type: .richText,
                text: text,
                data: rtfData,
                timestamp: Date()
            )
        }
        
        // Check for file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            let paths = urls.map { $0.path }.joined(separator: "\n")
            return ClipboardContent(
                type: .fileURL,
                text: paths,
                data: nil,
                timestamp: Date()
            )
        }
        
        // Check for image
        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return ClipboardContent(
                type: .image,
                text: nil,
                data: imageData,
                timestamp: Date()
            )
        }
        
        return nil
    }
    
    func getText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
    
    // MARK: - Content Setting
    
    func setText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func setRichText(_ rtfData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(rtfData, forType: .rtf)
    }
    
    // MARK: - History
    
    private func addToHistory(_ content: ClipboardContent) {
        // Avoid duplicates
        if let last = history.first, last.text == content.text {
            return
        }
        
        history.insert(content, at: 0)
        
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
    }
    
    func clearHistory() {
        history.removeAll()
    }
    
    // MARK: - Legal Content Detection
    
    func isLegalContent(_ text: String) -> Bool {
        let analyzer = DocumentAnalyzer.shared
        let docType = analyzer.detectDocumentType(from: text)
        return docType != .unknown
    }
    
    func analyzeClipboardContent() -> ClipboardAnalysis? {
        guard let content = currentContent, let text = content.text else {
            return nil
        }
        
        let analyzer = DocumentAnalyzer.shared
        
        return ClipboardAnalysis(
            documentType: analyzer.detectDocumentType(from: text),
            wordCount: text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
            characterCount: text.count,
            legalTerms: analyzer.detectLegalTerms(in: text),
            riskIndicators: analyzer.detectRiskIndicators(in: text),
            summary: analyzer.generateQuickSummary(of: text)
        )
    }
}

// MARK: - Supporting Types

struct ClipboardContent: Identifiable, Equatable {
    let id = UUID()
    let type: ClipboardContentType
    let text: String?
    let data: Data?
    let timestamp: Date
    
    static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        lhs.id == rhs.id
    }
}

enum ClipboardContentType {
    case text
    case richText
    case fileURL
    case image
    case other
}

struct ClipboardAnalysis {
    let documentType: DocumentType
    let wordCount: Int
    let characterCount: Int
    let legalTerms: [LegalTerm]
    let riskIndicators: [RiskIndicator]
    let summary: String
}
