import Foundation
import Combine

/// Main context engine that coordinates all context detection services
final class ContextEngine {
    static let shared = ContextEngine()
    
    @Published private(set) var currentContext: EnrichedContext?
    @Published private(set) var suggestedTools: [Tool] = []
    @Published private(set) var contextConfidence: Double = 0
    
    private let accessibilityService = AccessibilityService.shared
    private let appMonitorService = AppMonitorService.shared
    private let selectionService = SelectionService.shared
    private let clipboardService = ClipboardService.shared
    private let documentAnalyzer = DocumentAnalyzer.shared
    private let toolService = ToolService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var contextUpdateTimer: Timer?
    
    private init() {
        setupBindings()
    }
    
    // MARK: - Lifecycle
    
    func start() {
        guard accessibilityService.hasAccessibilityPermission else {
            logWarning("Accessibility permission not granted", category: .context)
            return
        }
        
        selectionService.startMonitoring()
        clipboardService.startMonitoring()
        startContextUpdates()
        
        logInfo("Context engine started", category: .context)
    }
    
    func stop() {
        selectionService.stopMonitoring()
        clipboardService.stopMonitoring()
        stopContextUpdates()
        
        logInfo("Context engine stopped", category: .context)
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // App changes
        appMonitorService.$activeApp
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateContext()
            }
            .store(in: &cancellables)
        
        // Window changes
        appMonitorService.$activeWindow
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateContext()
            }
            .store(in: &cancellables)
        
        // Selection changes
        selectionService.$currentSelection
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateContext()
            }
            .store(in: &cancellables)
    }
    
    private func startContextUpdates() {
        contextUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateContext()
        }
        
        // Initial update
        updateContext()
    }
    
    private func stopContextUpdates() {
        contextUpdateTimer?.invalidate()
        contextUpdateTimer = nil
    }
    
    // MARK: - Context Building
    
    private func updateContext() {
        let context = buildContext()
        
        // Only update if context changed significantly
        if shouldUpdateContext(newContext: context) {
            currentContext = context
            updateSuggestedTools(for: context)
            
            logDebug("Context updated: \(context.summary)", category: .context)
        }
    }
    
    private func buildContext() -> EnrichedContext {
        let app = appMonitorService.activeApp
        let window = appMonitorService.activeWindow
        let selection = selectionService.currentSelection
        let appClassification = appMonitorService.classifyActiveApp()
        
        // Determine document type
        var documentType: DocumentType = .unknown
        var confidence: Double = 0.3
        
        // From window title/file name
        if let fileName = window?.fileName {
            documentType = documentAnalyzer.detectDocumentType(fromFileName: fileName)
            if documentType != .unknown {
                confidence = 0.7
            }
        }
        
        // From selected text (higher confidence)
        if let text = selection?.text, text.count > 50 {
            let detectedType = documentAnalyzer.detectDocumentType(from: text)
            if detectedType != .unknown {
                documentType = detectedType
                confidence = 0.85
            }
        }
        
        // Analyze content
        var legalTerms: [LegalTerm] = []
        var riskIndicators: [RiskIndicator] = []
        var entities: [ExtractedEntity] = []
        
        if let text = selection?.text {
            legalTerms = documentAnalyzer.detectLegalTerms(in: text)
            riskIndicators = documentAnalyzer.detectRiskIndicators(in: text)
            entities = documentAnalyzer.extractKeyEntities(from: text)
            
            // Boost confidence if legal content detected
            if !legalTerms.isEmpty {
                confidence = min(confidence + 0.1, 1.0)
            }
        }
        
        contextConfidence = confidence
        
        return EnrichedContext(
            app: app,
            window: window,
            appClassification: appClassification,
            documentType: documentType,
            selectedText: selection?.text,
            legalTerms: legalTerms,
            riskIndicators: riskIndicators,
            entities: entities,
            confidence: confidence,
            timestamp: Date()
        )
    }
    
    private func shouldUpdateContext(newContext: EnrichedContext) -> Bool {
        guard let current = currentContext else { return true }
        
        // Different app
        if current.app?.bundleIdentifier != newContext.app?.bundleIdentifier {
            return true
        }
        
        // Different window
        if current.window?.title != newContext.window?.title {
            return true
        }
        
        // Different document type
        if current.documentType != newContext.documentType {
            return true
        }
        
        // Significant selection change
        if current.selectedText != newContext.selectedText {
            let currentLen = current.selectedText?.count ?? 0
            let newLen = newContext.selectedText?.count ?? 0
            if abs(currentLen - newLen) > 50 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Tool Suggestions
    
    private func updateSuggestedTools(for context: EnrichedContext) {
        var toolIds: [String] = []
        
        // Based on document type
        if let docType = context.documentType as DocumentType? {
            toolIds.append(contentsOf: docType.suggestedTools)
        }
        
        // Based on app classification
        let categories = context.appClassification.suggestedToolCategories
        for category in categories.prefix(2) {
            if let tools = toolService.categories[category] {
                toolIds.append(contentsOf: tools.prefix(2).map { $0.id })
            }
        }
        
        // Based on risk indicators
        if !context.riskIndicators.isEmpty {
            toolIds.insert("contract_risk_analyzer", at: 0)
        }
        
        // Remove duplicates and fetch tools
        let uniqueIds = Array(Set(toolIds)).prefix(6)
        suggestedTools = toolService.allTools.filter { uniqueIds.contains($0.id) }
        
        // Update app state
        AppState.shared.suggestedTools = suggestedTools
    }
    
    // MARK: - Quick Actions
    
    func getQuickActions() -> [QuickAction] {
        guard let context = currentContext else {
            return QuickAction.defaults
        }
        
        var actions: [QuickAction] = []
        
        // Document-specific actions
        switch context.documentType {
        case .contract:
            actions.append(QuickAction(id: "analyze", label: "Analyze Risks", icon: "exclamationmark.shield", toolId: "contract_risk_analyzer"))
            actions.append(QuickAction(id: "summarize", label: "Summarize", icon: "doc.text", toolId: "contract_summarizer"))
            actions.append(QuickAction(id: "clauses", label: "Extract Clauses", icon: "list.bullet", toolId: "clause_extractor"))
            
        case .brief, .motion:
            actions.append(QuickAction(id: "research", label: "Find Cases", icon: "magnifyingglass", toolId: "case_law_finder"))
            actions.append(QuickAction(id: "citations", label: "Check Citations", icon: "checkmark.circle", toolId: "citation_validator"))
            actions.append(QuickAction(id: "summarize", label: "Summarize", icon: "doc.text", toolId: "document_summarizer"))
            
        case .email:
            actions.append(QuickAction(id: "reply", label: "Draft Reply", icon: "arrowshape.turn.up.left", toolId: "email_response_generator"))
            actions.append(QuickAction(id: "tone", label: "Check Tone", icon: "face.smiling", toolId: "tone_analyzer"))
            
        default:
            actions = QuickAction.defaults
        }
        
        // Add risk-based action if risks detected
        if !context.riskIndicators.isEmpty && !actions.contains(where: { $0.id == "analyze" }) {
            actions.insert(QuickAction(id: "analyze", label: "Check Risks", icon: "exclamationmark.shield", toolId: "contract_risk_analyzer"), at: 0)
        }
        
        return Array(actions.prefix(4))
    }
}

// MARK: - Enriched Context

struct EnrichedContext {
    let app: RunningApplication?
    let window: WindowInfo?
    let appClassification: AppClassification
    let documentType: DocumentType
    let selectedText: String?
    let legalTerms: [LegalTerm]
    let riskIndicators: [RiskIndicator]
    let entities: [ExtractedEntity]
    let confidence: Double
    let timestamp: Date
    
    var hasSelection: Bool {
        selectedText != nil && !selectedText!.isEmpty
    }
    
    var hasLegalContent: Bool {
        !legalTerms.isEmpty || documentType != .unknown
    }
    
    var summary: String {
        var parts: [String] = []
        
        if let appName = app?.localizedName {
            parts.append(appName)
        }
        
        if documentType != .unknown {
            parts.append(documentType.rawValue)
        }
        
        if hasSelection {
            parts.append("\(selectedText!.count) chars selected")
        }
        
        return parts.joined(separator: " | ")
    }
}
