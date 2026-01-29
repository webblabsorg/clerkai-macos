import Foundation
import AppKit
import Combine

/// Service for detecting context from active applications
final class ContextDetectionService {
    static let shared = ContextDetectionService()
    
    @Published private(set) var currentContext: DetectedContext?
    
    private var cancellables = Set<AnyCancellable>()
    private var pollTimer: Timer?
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe active app changes
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                self?.handleAppActivation(notification)
            }
            .store(in: &cancellables)
        
        // Start polling for context
        startPolling()
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.detectContext()
        }
    }
    
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    // MARK: - Detection
    
    private func handleAppActivation(_ notification: Notification) {
        detectContext()
    }
    
    func detectContext() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        
        let bundleId = frontApp.bundleIdentifier ?? "unknown"
        let sourceApp = SourceApp(rawValue: bundleId) ?? .unknown
        
        // Get window title
        let windowTitle = getActiveWindowTitle()
        
        // Detect document type from window title
        let documentType = detectDocumentType(from: windowTitle)
        
        // Get selected text if available
        let selectedText = getSelectedText()
        
        let context = DetectedContext(
            sourceApp: sourceApp,
            documentType: documentType,
            selectedText: selectedText,
            windowTitle: windowTitle,
            filePath: nil,
            detectedAt: Date()
        )
        
        // Only update if context changed
        if context != currentContext {
            currentContext = context
            updateSuggestedTools(for: context)
        }
    }
    
    // MARK: - Window Title
    
    private func getActiveWindowTitle() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        // Use Accessibility API to get window title
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard result == .success, let window = focusedWindow else { return nil }
        
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
        
        guard titleResult == .success, let titleString = title as? String else { return nil }
        
        return titleString
    }
    
    // MARK: - Document Type Detection
    
    private func detectDocumentType(from windowTitle: String?) -> DocumentType? {
        guard let title = windowTitle?.lowercased() else { return nil }
        
        // Contract indicators
        if title.contains("contract") || title.contains("agreement") ||
           title.contains("terms") || title.contains("nda") {
            return .contract
        }
        
        // Brief/Motion indicators
        if title.contains("brief") || title.contains("motion") ||
           title.contains("memorandum") {
            return .brief
        }
        
        // Email indicators
        if title.contains("mail") || title.contains("inbox") ||
           title.contains("compose") || title.contains("reply") {
            return .email
        }
        
        // PDF indicators
        if title.hasSuffix(".pdf") {
            return .pdf
        }
        
        // Spreadsheet indicators
        if title.contains("excel") || title.contains("numbers") ||
           title.hasSuffix(".xlsx") || title.hasSuffix(".csv") {
            return .spreadsheet
        }
        
        // Presentation indicators
        if title.contains("powerpoint") || title.contains("keynote") ||
           title.hasSuffix(".pptx") || title.hasSuffix(".key") {
            return .presentation
        }
        
        return .unknown
    }
    
    // MARK: - Selected Text
    
    private func getSelectedText() -> String? {
        // Try to get selected text via Accessibility API
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else { return nil }
        
        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        
        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else { return nil }
        
        return text
    }
    
    // MARK: - Tool Suggestions
    
    private func updateSuggestedTools(for context: DetectedContext) {
        var suggestedToolIds: [String] = []
        
        // Add tools based on document type
        if let docType = context.documentType {
            suggestedToolIds.append(contentsOf: docType.suggestedTools)
        }
        
        // Add tools based on source app
        let categories = context.sourceApp.suggestedCategories
        // TODO: Fetch tools from these categories
        
        // Update app state
        // AppState.shared.suggestedTools = fetchTools(ids: suggestedToolIds)
    }
}
