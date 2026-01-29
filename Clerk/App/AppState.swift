import Foundation
import Combine
import SwiftUI

/// Global application state manager
final class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - UI State
    @Published var currentUIState: UIState = .minimized
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    
    // MARK: - Theme
    @Published var currentTheme: AppTheme = .system
    @Published var effectiveColorScheme: ColorScheme = .dark
    
    // MARK: - Localization
    @Published var currentLocale: Locale = .current
    @Published var supportedLanguages: [Language] = Language.allSupported
    
    // MARK: - Context
    @Published var detectedContext: DetectedContext?
    @Published var suggestedTools: [Tool] = []
    
    // MARK: - Tool Execution
    @Published var currentTool: Tool?
    @Published var isExecutingTool: Bool = false
    @Published var executionProgress: Double = 0.0
    
    // MARK: - Subscriptions
    @Published var subscriptionTier: SubscriptionTier = .free
    @Published var usageStats: UsageStats?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
        loadPersistedState()
    }
    
    private func setupObservers() {
        // Monitor system appearance changes
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                self?.updateEffectiveColorScheme()
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedState() {
        // Load persisted preferences
        if let themeRaw = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
        }
        
        updateEffectiveColorScheme()
    }
    
    private func updateEffectiveColorScheme() {
        switch currentTheme {
        case .light, .cream:
            effectiveColorScheme = .light
        case .dark, .chocolate:
            effectiveColorScheme = .dark
        case .system:
            let appearance = NSApp.effectiveAppearance
            effectiveColorScheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }
    
    // MARK: - State Transitions
    
    func transitionTo(_ state: UIState) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentUIState = state
        }
    }
    
    func setTool(_ tool: Tool) {
        currentTool = tool
        transitionTo(.toolExecution)
    }
    
    func clearTool() {
        currentTool = nil
        isExecutingTool = false
        executionProgress = 0.0
        transitionTo(.expanded)
    }
}

// MARK: - UI State Enum

enum UIState: String, CaseIterable {
    case minimized   // 48x48 avatar
    case compact     // Toolbar with quick actions
    case expanded    // Full panel with categories
    case toolExecution // Tool input/output view
}

// MARK: - Theme Enum

enum AppTheme: String, CaseIterable {
    case system
    case light      // Deep White
    case dark       // Deep Black
    case cream      // Deep Cream
    case chocolate  // Deep Chocolate
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .cream: return "Cream"
        case .chocolate: return "Chocolate"
        }
    }
}

// MARK: - Subscription Tier

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro
    case plus
    case team
    case enterprise
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var monthlyPrice: Decimal? {
        switch self {
        case .free: return 0
        case .pro: return 29
        case .plus: return 49
        case .team: return 39 // per user
        case .enterprise: return nil // custom
        }
    }
}
