import SwiftUI
import AppKit

// MARK: - Accessibility Modifiers

extension View {
    /// Adds accessibility label and hint for VoiceOver
    func accessibilityTool(name: String, description: String) -> some View {
        self
            .accessibilityLabel(name)
            .accessibilityHint(description)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Marks view as a heading for VoiceOver navigation
    func accessibilityHeading(_ level: AccessibilityHeadingLevel = .h2) -> some View {
        self.accessibilityAddTraits(.isHeader)
    }
    
    /// Adds keyboard shortcut hint for accessibility
    func accessibilityKeyboardShortcut(_ shortcut: String) -> some View {
        self.accessibilityHint("Keyboard shortcut: \(shortcut)")
    }
}

// MARK: - Focus Management

struct FocusableModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    var onFocus: (() -> Void)?
    var onBlur: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    onFocus?()
                } else {
                    onBlur?()
                }
            }
    }
}

extension View {
    func focusable(onFocus: (() -> Void)? = nil, onBlur: (() -> Void)? = nil) -> some View {
        modifier(FocusableModifier(onFocus: onFocus, onBlur: onBlur))
    }
}

// MARK: - High Contrast Support

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var normalBackground: Color
    var highContrastBackground: Color
    
    func body(content: Content) -> some View {
        content
            .background(reduceTransparency ? highContrastBackground : normalBackground)
    }
}

extension View {
    func highContrastBackground(normal: Color, highContrast: Color) -> some View {
        modifier(HighContrastModifier(normalBackground: normal, highContrastBackground: highContrast))
    }
}

// MARK: - Reduced Motion Support

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var animation: Animation
    var reducedAnimation: Animation
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

extension View {
    func accessibleAnimation(_ animation: Animation, reduced: Animation? = nil) -> some View {
        modifier(ReducedMotionModifier(animation: animation, reducedAnimation: reduced ?? .default))
    }
}

// MARK: - Keyboard Navigation

struct KeyboardNavigableModifier: ViewModifier {
    var onEnter: () -> Void
    var onEscape: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onKeyPress(.return) {
                onEnter()
                return .handled
            }
            .onKeyPress(.escape) {
                onEscape?()
                return onEscape != nil ? .handled : .ignored
            }
            .onKeyPress(.upArrow) {
                onArrowUp?()
                return onArrowUp != nil ? .handled : .ignored
            }
            .onKeyPress(.downArrow) {
                onArrowDown?()
                return onArrowDown != nil ? .handled : .ignored
            }
    }
}

extension View {
    func keyboardNavigable(
        onEnter: @escaping () -> Void,
        onEscape: (() -> Void)? = nil,
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil
    ) -> some View {
        modifier(KeyboardNavigableModifier(
            onEnter: onEnter,
            onEscape: onEscape,
            onArrowUp: onArrowUp,
            onArrowDown: onArrowDown
        ))
    }
}

// MARK: - Screen Reader Announcements

final class ScreenReaderAnnouncer {
    static let shared = ScreenReaderAnnouncer()
    
    private init() {}
    
    func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        let notification: NSAccessibility.Notification
        
        switch priority {
        case .high:
            notification = .announcementRequested
        case .normal:
            notification = .announcementRequested
        case .low:
            notification = .announcementRequested
        }
        
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: notification,
            userInfo: [
                .announcement: message,
                .priority: priority == .high ? NSAccessibilityPriorityLevel.high : NSAccessibilityPriorityLevel.medium
            ]
        )
    }
    
    func announceToolExecution(toolName: String) {
        announce("Running \(toolName)", priority: .normal)
    }
    
    func announceToolComplete(toolName: String, success: Bool) {
        let message = success ? "\(toolName) completed successfully" : "\(toolName) failed"
        announce(message, priority: .high)
    }
    
    func announceRiskScore(_ score: Double) {
        let level = OutputFormatter.shared.riskLabel(for: score)
        announce("Risk score: \(String(format: "%.1f", score)) out of 10. \(level)", priority: .high)
    }
}

enum AnnouncementPriority {
    case high
    case normal
    case low
}

// MARK: - Accessibility Labels

struct AccessibilityLabels {
    static let avatarButton = "Clerk AI Assistant"
    static let avatarHint = "Click to expand toolbar, double-click for full panel"
    
    static let expandButton = "Expand panel"
    static let collapseButton = "Collapse panel"
    static let closeButton = "Close panel"
    
    static let searchField = "Search tools"
    static let searchHint = "Search through 301 legal AI tools"
    
    static func toolCard(name: String, category: String) -> String {
        "\(name) tool in \(category) category"
    }
    
    static func categoryRow(name: String, count: Int) -> String {
        "\(name) category with \(count) tools"
    }
    
    static func riskIndicator(severity: String, title: String) -> String {
        "\(severity) risk: \(title)"
    }
    
    static func progressIndicator(percent: Int) -> String {
        "Progress: \(percent) percent"
    }
}
