import Foundation
import AppKit
import Combine

/// Service for monitoring active application changes
final class AppMonitorService {
    static let shared = AppMonitorService()
    
    @Published private(set) var activeApp: RunningApplication?
    @Published private(set) var activeWindow: WindowInfo?
    
    private var cancellables = Set<AnyCancellable>()
    private let accessibilityService = AccessibilityService.shared
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // App activation
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                self?.handleAppActivation(notification)
            }
            .store(in: &cancellables)
        
        // App deactivation
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didDeactivateApplicationNotification)
            .sink { [weak self] _ in
                self?.updateActiveApp()
            }
            .store(in: &cancellables)
        
        // App launch
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] _ in
                self?.updateActiveApp()
            }
            .store(in: &cancellables)
        
        // App termination
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] _ in
                self?.updateActiveApp()
            }
            .store(in: &cancellables)
        
        // Initial update
        updateActiveApp()
    }
    
    // MARK: - Handlers
    
    private func handleAppActivation(_ notification: Notification) {
        updateActiveApp()
        updateActiveWindow()
    }
    
    private func updateActiveApp() {
        activeApp = accessibilityService.getActiveApplication()
    }
    
    private func updateActiveWindow() {
        activeWindow = accessibilityService.getActiveWindowInfo()
    }
    
    // MARK: - App Classification
    
    func classifyActiveApp() -> AppClassification {
        guard let app = activeApp else { return .unknown }
        
        let bundleId = app.bundleIdentifier.lowercased()
        
        // Document editors
        if bundleId.contains("word") || bundleId.contains("pages") ||
           bundleId.contains("docs") || bundleId.contains("writer") {
            return .documentEditor
        }
        
        // PDF viewers
        if bundleId.contains("preview") || bundleId.contains("acrobat") ||
           bundleId.contains("pdf") {
            return .pdfViewer
        }
        
        // Email clients
        if bundleId.contains("mail") || bundleId.contains("outlook") ||
           bundleId.contains("thunderbird") || bundleId.contains("spark") {
            return .emailClient
        }
        
        // Browsers
        if bundleId.contains("safari") || bundleId.contains("chrome") ||
           bundleId.contains("firefox") || bundleId.contains("edge") ||
           bundleId.contains("brave") || bundleId.contains("arc") {
            return .browser
        }
        
        // Spreadsheets
        if bundleId.contains("excel") || bundleId.contains("numbers") ||
           bundleId.contains("sheets") {
            return .spreadsheet
        }
        
        // Presentations
        if bundleId.contains("powerpoint") || bundleId.contains("keynote") ||
           bundleId.contains("slides") {
            return .presentation
        }
        
        // Note taking
        if bundleId.contains("notes") || bundleId.contains("notion") ||
           bundleId.contains("evernote") || bundleId.contains("bear") {
            return .noteTaking
        }
        
        // Code editors
        if bundleId.contains("xcode") || bundleId.contains("vscode") ||
           bundleId.contains("sublime") || bundleId.contains("atom") {
            return .codeEditor
        }
        
        return .other
    }
    
    // MARK: - Running Apps
    
    func getRunningApps() -> [RunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { app in
                RunningApplication(
                    bundleIdentifier: app.bundleIdentifier ?? "unknown",
                    localizedName: app.localizedName ?? "Unknown",
                    processIdentifier: app.processIdentifier,
                    isActive: app.isActive
                )
            }
    }
    
    func isAppRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }
}

// MARK: - App Classification

enum AppClassification: String, CaseIterable {
    case documentEditor
    case pdfViewer
    case emailClient
    case browser
    case spreadsheet
    case presentation
    case noteTaking
    case codeEditor
    case other
    case unknown
    
    var suggestedToolCategories: [ToolCategory] {
        switch self {
        case .documentEditor:
            return [.documentDrafting, .contractReview, .legalResearch]
        case .pdfViewer:
            return [.contractReview, .documentDrafting, .litigationSupport]
        case .emailClient:
            return [.clientCommunication, .documentDrafting]
        case .browser:
            return [.legalResearch, .compliance]
        case .spreadsheet:
            return [.practiceManagement, .taxLaw]
        case .presentation:
            return [.litigationSupport, .clientCommunication]
        case .noteTaking:
            return [.documentDrafting, .legalResearch]
        case .codeEditor:
            return [.intellectualProperty, .compliance]
        case .other, .unknown:
            return [.documentDrafting, .legalResearch]
        }
    }
}
