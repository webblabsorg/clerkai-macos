import Foundation
import AppKit

/// Centralized error handling and reporting
final class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Error Handling
    
    func handle(_ error: Error, context: ErrorContext = .general, showAlert: Bool = false) {
        // Log the error
        logError(error, context: context)
        
        // Report to crash reporting service
        reportError(error, context: context)
        
        // Show alert if requested
        if showAlert {
            showErrorAlert(error, context: context)
        }
    }
    
    func handleWithRecovery(_ error: Error, context: ErrorContext = .general, recovery: @escaping () -> Void) {
        logError(error, context: context)
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = self.errorTitle(for: context)
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Retry")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                recovery()
            }
        }
    }
    
    // MARK: - Logging
    
    private func logError(_ error: Error, context: ErrorContext) {
        let category: LogCategory
        switch context {
        case .general: category = .general
        case .network: category = .network
        case .auth: category = .auth
        case .ai: category = .ai
        case .context: category = .context
        case .ui: category = .ui
        }
        
        Logger.shared.error(error, category: category)
    }
    
    // MARK: - Reporting
    
    private func reportError(_ error: Error, context: ErrorContext) {
        // TODO: Integrate with Sentry or similar crash reporting
        #if !DEBUG
        // Send to crash reporting service
        #endif
    }
    
    // MARK: - Alerts
    
    private func showErrorAlert(_ error: Error, context: ErrorContext) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = self.errorTitle(for: context)
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func errorTitle(for context: ErrorContext) -> String {
        switch context {
        case .general: return "An Error Occurred"
        case .network: return "Network Error"
        case .auth: return "Authentication Error"
        case .ai: return "AI Service Error"
        case .context: return "Context Detection Error"
        case .ui: return "Display Error"
        }
    }
    
    // MARK: - User-Friendly Messages
    
    func userMessage(for error: Error) -> String {
        switch error {
        case let apiError as APIError:
            return apiError.errorDescription ?? "An unexpected error occurred."
            
        case let authError as AuthError:
            return authError.errorDescription ?? "Authentication failed."
            
        case let aiError as AIServiceError:
            return aiError.errorDescription ?? "AI service unavailable."
            
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network."
            case .timedOut:
                return "Request timed out. Please try again."
            case .cancelled:
                return "Request was cancelled."
            default:
                return "Network error. Please try again."
            }
            
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Error Context

enum ErrorContext {
    case general
    case network
    case auth
    case ai
    case context
    case ui
}

// MARK: - App-Specific Errors

enum ClerkError: LocalizedError {
    case toolNotFound(String)
    case invalidInput(String)
    case quotaExceeded
    case featureNotAvailable(SubscriptionTier)
    case contextDetectionFailed
    case exportFailed
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let id):
            return "Tool '\(id)' not found."
        case .invalidInput(let field):
            return "Invalid input for '\(field)'."
        case .quotaExceeded:
            return "You've reached your usage limit. Upgrade to continue."
        case .featureNotAvailable(let tier):
            return "This feature requires \(tier.displayName) or higher."
        case .contextDetectionFailed:
            return "Unable to detect context. Please grant accessibility permissions."
        case .exportFailed:
            return "Failed to export. Please try again."
        case .importFailed:
            return "Failed to import. The file may be corrupted."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .quotaExceeded:
            return "Upgrade your plan to get unlimited access."
        case .featureNotAvailable:
            return "Upgrade your plan to unlock this feature."
        case .contextDetectionFailed:
            return "Open System Preferences > Security & Privacy > Accessibility and add Clerk."
        default:
            return nil
        }
    }
}
