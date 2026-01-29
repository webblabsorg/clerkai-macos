import Foundation
import AppKit

/// Integration with email clients for content extraction
/// 
/// Note on platform limitations:
/// - Mail.app: Scripting is limited in macOS 12+. We use best-effort AppleScript for subject/sender
///   but fall back to AX/window-title parsing when scripting fails.
/// - Outlook for Mac: Different scripting model than Windows. We attempt AppleScript but expect failures.
/// - Other clients (Spark, MailMate, Postbox): AX-based extraction only.
/// 
/// For reliable email content access, users should select text and use clipboard-based workflows,
/// or use webmail (Gmail/Outlook Web) which is handled by BrowserIntegration.
final class EmailIntegration {
    static let shared = EmailIntegration()
    
    private let accessibilityService = AccessibilityService.shared
    private let appleScript = AppleScriptRunner.shared
    
    private let supportedApps: [String: EmailClient] = [
        "com.apple.mail": .appleMail,
        "com.microsoft.Outlook": .outlook,
        "com.readdle.smartemail-Mac": .spark,
        "com.freron.MailMate": .mailMate,
        "com.postbox-inc.postbox": .postbox
    ]
    
    private init() {}
    
    // MARK: - Detection
    
    var isEmailClientActive: Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return supportedApps.keys.contains(bundleId)
    }
    
    var activeEmailClient: EmailClient? {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return nil
        }
        return supportedApps[bundleId]
    }
    
    // MARK: - Content Extraction
    
    func getEmailContent() -> EmailContent? {
        guard isEmailClientActive else { return nil }
        
        let client = activeEmailClient ?? .unknown
        let windowInfo = accessibilityService.getActiveWindowInfo()
        let selectedText = accessibilityService.getSelectedText()
        let fullText = accessibilityService.getTextContent()
        
        // Try AppleScript for Mail.app and Outlook (best-effort)
        var subject: String?
        var sender: String?
        
        if client == .appleMail {
            (subject, sender) = getMailAppMetadataViaAppleScript()
        } else if client == .outlook {
            (subject, sender) = getOutlookMetadataViaAppleScript()
        }
        
        // Fallback to window title parsing
        if subject == nil || sender == nil {
            let parsed = parseEmailMetadata(from: windowInfo?.title)
            subject = subject ?? parsed.subject
            sender = sender ?? parsed.sender
        }
        
        // Detect if composing or reading
        let mode = detectEmailMode(windowTitle: windowInfo?.title)
        
        return EmailContent(
            client: client,
            mode: mode,
            subject: subject,
            sender: sender,
            selectedText: selectedText,
            bodyText: fullText,
            timestamp: Date()
        )
    }
    
    // MARK: - AppleScript Extraction (Best-Effort)
    
    private func getMailAppMetadataViaAppleScript() -> (subject: String?, sender: String?) {
        // Mail.app scripting is limited in macOS 12+ but we try anyway
        let scriptSubject = """
        tell application "Mail"
            try
                set theMessages to selection
                if (count of theMessages) > 0 then
                    return subject of item 1 of theMessages
                end if
            end try
            return ""
        end tell
        """
        
        let scriptSender = """
        tell application "Mail"
            try
                set theMessages to selection
                if (count of theMessages) > 0 then
                    return sender of item 1 of theMessages
                end if
            end try
            return ""
        end tell
        """
        
        var subject: String?
        var sender: String?
        
        if let value = try? appleScript.runString(scriptSubject), !value.isEmpty {
            subject = value
        }
        if let value = try? appleScript.runString(scriptSender), !value.isEmpty {
            sender = value
        }
        
        return (subject, sender)
    }
    
    private func getOutlookMetadataViaAppleScript() -> (subject: String?, sender: String?) {
        // Outlook for Mac has different scripting; this may fail
        let scriptSubject = """
        tell application "Microsoft Outlook"
            try
                set theMessages to selected objects
                if (count of theMessages) > 0 then
                    return subject of item 1 of theMessages
                end if
            end try
            return ""
        end tell
        """
        
        let scriptSender = """
        tell application "Microsoft Outlook"
            try
                set theMessages to selected objects
                if (count of theMessages) > 0 then
                    return sender of item 1 of theMessages
                end if
            end try
            return ""
        end tell
        """
        
        var subject: String?
        var sender: String?
        
        if let value = try? appleScript.runString(scriptSubject), !value.isEmpty {
            subject = value
        }
        if let value = try? appleScript.runString(scriptSender), !value.isEmpty {
            sender = value
        }
        
        return (subject, sender)
    }
    
    private func parseEmailMetadata(from title: String?) -> (subject: String?, sender: String?) {
        guard let title = title else { return (nil, nil) }
        
        // Apple Mail: "Subject - Sender"
        // Outlook: "Subject"
        // Try to extract subject
        var subject: String? = title
        var sender: String?
        
        // Remove common suffixes
        let suffixes = [" - Mail", " - Outlook", " - Spark"]
        for suffix in suffixes {
            if let range = title.range(of: suffix) {
                subject = String(title[..<range.lowerBound])
                break
            }
        }
        
        // Try to extract sender from "Subject - Sender" format
        if let dashRange = subject?.range(of: " - ", options: .backwards) {
            sender = String(subject![dashRange.upperBound...])
            subject = String(subject![..<dashRange.lowerBound])
        }
        
        return (subject, sender)
    }
    
    private func detectEmailMode(windowTitle: String?) -> EmailMode {
        guard let title = windowTitle?.lowercased() else { return .unknown }
        
        if title.contains("new message") || title.contains("compose") ||
           title.contains("reply") || title.contains("forward") ||
           title.hasPrefix("re:") || title.hasPrefix("fwd:") {
            return .composing
        }
        
        return .reading
    }
    
    // MARK: - Email Analysis
    
    func analyzeCurrentEmail() -> EmailAnalysisResult? {
        guard let content = getEmailContent() else { return nil }
        
        let textToAnalyze = content.selectedText ?? content.bodyText ?? ""
        guard !textToAnalyze.isEmpty else { return nil }
        
        let analyzer = DocumentAnalyzer.shared
        
        // Detect email type
        let emailType = detectEmailType(from: textToAnalyze, subject: content.subject)
        
        return EmailAnalysisResult(
            emailType: emailType,
            tone: analyzeTone(textToAnalyze),
            legalTerms: analyzer.detectLegalTerms(in: textToAnalyze),
            suggestedActions: getSuggestedActions(for: emailType, mode: content.mode),
            wordCount: textToAnalyze.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        )
    }
    
    private func detectEmailType(from text: String, subject: String?) -> EmailType {
        let combined = (subject ?? "") + " " + text
        let lowercased = combined.lowercased()
        
        // Contract-related
        if lowercased.contains("contract") || lowercased.contains("agreement") ||
           lowercased.contains("sign") || lowercased.contains("execute") {
            return .contractRelated
        }
        
        // Legal matter
        if lowercased.contains("litigation") || lowercased.contains("lawsuit") ||
           lowercased.contains("court") || lowercased.contains("deposition") {
            return .legalMatter
        }
        
        // Client communication
        if lowercased.contains("dear client") || lowercased.contains("update on your") ||
           lowercased.contains("status of") || lowercased.contains("regarding your case") {
            return .clientUpdate
        }
        
        // Billing
        if lowercased.contains("invoice") || lowercased.contains("billing") ||
           lowercased.contains("payment") || lowercased.contains("retainer") {
            return .billing
        }
        
        // Meeting/scheduling
        if lowercased.contains("meeting") || lowercased.contains("schedule") ||
           lowercased.contains("calendar") || lowercased.contains("availability") {
            return .scheduling
        }
        
        return .general
    }
    
    private func analyzeTone(_ text: String) -> EmailTone {
        let lowercased = text.lowercased()
        
        // Urgent indicators
        if lowercased.contains("urgent") || lowercased.contains("immediately") ||
           lowercased.contains("asap") || lowercased.contains("deadline") {
            return .urgent
        }
        
        // Formal indicators
        if lowercased.contains("pursuant to") || lowercased.contains("hereby") ||
           lowercased.contains("respectfully") || lowercased.contains("kindly") {
            return .formal
        }
        
        // Friendly indicators
        if lowercased.contains("hope you're well") || lowercased.contains("thanks so much") ||
           lowercased.contains("appreciate") {
            return .friendly
        }
        
        return .neutral
    }
    
    private func getSuggestedActions(for emailType: EmailType, mode: EmailMode) -> [String] {
        var actions: [String] = []
        
        if mode == .reading {
            actions.append("Draft Reply")
        }
        
        switch emailType {
        case .contractRelated:
            actions.append("Analyze Contract")
            actions.append("Check Risks")
        case .legalMatter:
            actions.append("Research Case Law")
            actions.append("Summarize Issue")
        case .clientUpdate:
            actions.append("Generate Status Report")
        case .billing:
            actions.append("Review Time Entries")
        case .scheduling:
            actions.append("Check Conflicts")
        case .general:
            actions.append("Summarize")
        }
        
        return actions
    }
    
    // MARK: - Actions
    
    func insertText(_ text: String) {
        guard isEmailClientActive else { return }
        SelectionService.shared.pasteText(text)
    }
}

// MARK: - Supporting Types

enum EmailClient: String {
    case appleMail
    case outlook
    case spark
    case mailMate
    case postbox
    case unknown
}

enum EmailMode {
    case reading
    case composing
    case unknown
}

struct EmailContent {
    let client: EmailClient
    let mode: EmailMode
    let subject: String?
    let sender: String?
    let selectedText: String?
    let bodyText: String?
    let timestamp: Date
    
    var hasSelection: Bool {
        selectedText != nil && !selectedText!.isEmpty
    }
}

enum EmailType {
    case contractRelated
    case legalMatter
    case clientUpdate
    case billing
    case scheduling
    case general
}

enum EmailTone {
    case formal
    case friendly
    case neutral
    case urgent
}

struct EmailAnalysisResult {
    let emailType: EmailType
    let tone: EmailTone
    let legalTerms: [LegalTerm]
    let suggestedActions: [String]
    let wordCount: Int
}
