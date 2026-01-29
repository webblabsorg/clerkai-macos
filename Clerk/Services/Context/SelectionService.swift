import Foundation
import AppKit
import Combine

/// Service for handling text selection across applications
final class SelectionService {
    static let shared = SelectionService()
    
    @Published private(set) var currentSelection: TextSelection?
    
    private let accessibilityService = AccessibilityService.shared
    private let appMonitorService = AppMonitorService.shared
    private var pollTimer: Timer?
    private var lastSelection: String?
    
    private init() {}
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForSelection()
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func checkForSelection() {
        guard let text = accessibilityService.getSelectedText(withTimeout: 0.6), text != lastSelection else {
            return
        }
        
        lastSelection = text
        
        let selection = TextSelection(
            text: text,
            sourceApp: appMonitorService.activeApp,
            windowInfo: appMonitorService.activeWindow,
            timestamp: Date()
        )
        
        currentSelection = selection
        
        // Notify context detection service
        NotificationCenter.default.post(
            name: .textSelectionChanged,
            object: selection
        )
    }
    
    // MARK: - Manual Selection
    
    func getSelectedText() -> String? {
        accessibilityService.getSelectedText()
    }
    
    func getSelectedText(promptForAccessibility: Bool, allowClipboardFallback: Bool) async -> String? {
        if accessibilityService.ensureAccessibilityPermission(prompt: promptForAccessibility) {
            if let text = accessibilityService.getSelectedText(), !text.isEmpty {
                return text
            }

            if allowClipboardFallback {
                return await captureSelectedTextViaClipboard(timeout: 0.6)
            }
        }

        return nil
    }
    
    func getSelectedTextWithContext() -> SelectionWithContext? {
        guard let text = accessibilityService.getSelectedText() else {
            return nil
        }
        
        let fullText = accessibilityService.getTextContent()
        
        return SelectionWithContext(
            selectedText: text,
            fullText: fullText,
            sourceApp: appMonitorService.activeApp,
            windowInfo: appMonitorService.activeWindow
        )
    }
    
    // MARK: - Selection Actions
    
    func copySelection() {
        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // C key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
    
    func pasteText(_ text: String) {
        // Set clipboard
        ClipboardService.shared.setText(text)
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
    
    func replaceSelection(with text: String) {
        pasteText(text)
    }
    
    // MARK: - Clipboard Fallback
    
    private func captureSelectedTextViaClipboard(timeout: TimeInterval) async -> String? {
        // Best-effort: this may still require Accessibility permission to synthesize Cmd+C.
        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)
        let originalChangeCount = pasteboard.changeCount

        await MainActor.run {
            self.copySelection()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != originalChangeCount {
                let value = pasteboard.string(forType: .string)
                // Restore clipboard (best-effort for text)
                if let originalString {
                    pasteboard.clearContents()
                    pasteboard.setString(originalString, forType: .string)
                } else {
                    // If there was no string, don't destroy other formats.
                    // We can't perfectly restore all pasteboard types here.
                }

                if let value, !value.isEmpty {
                    return value
                }
                return nil
            }

            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
            if Task.isCancelled {
                return nil
            }
        }

        // Timed out
        if let originalString {
            pasteboard.clearContents()
            pasteboard.setString(originalString, forType: .string)
        }

        return nil
    }
    
    // MARK: - Selection Analysis
    
    func analyzeSelection() -> SelectionAnalysis? {
        guard let selection = currentSelection else { return nil }
        
        let analyzer = DocumentAnalyzer.shared
        let text = selection.text
        
        return SelectionAnalysis(
            text: text,
            wordCount: text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
            documentType: analyzer.detectDocumentType(from: text),
            legalTerms: analyzer.detectLegalTerms(in: text),
            riskIndicators: analyzer.detectRiskIndicators(in: text),
            entities: analyzer.extractKeyEntities(from: text)
        )
    }
}

// MARK: - Supporting Types

struct TextSelection {
    let text: String
    let sourceApp: RunningApplication?
    let windowInfo: WindowInfo?
    let timestamp: Date
    
    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var isSubstantial: Bool {
        wordCount >= 10
    }
}

struct SelectionWithContext {
    let selectedText: String
    let fullText: String?
    let sourceApp: RunningApplication?
    let windowInfo: WindowInfo?
}

struct SelectionAnalysis {
    let text: String
    let wordCount: Int
    let documentType: DocumentType
    let legalTerms: [LegalTerm]
    let riskIndicators: [RiskIndicator]
    let entities: [ExtractedEntity]
    
    var hasLegalContent: Bool {
        !legalTerms.isEmpty || documentType != .unknown
    }
    
    var hasRisks: Bool {
        !riskIndicators.isEmpty
    }
    
    var highRiskCount: Int {
        riskIndicators.filter { $0.severity == .high }.count
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let textSelectionChanged = Notification.Name("com.clerk.textSelectionChanged")
}
