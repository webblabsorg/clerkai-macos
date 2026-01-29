import Foundation
import AppKit
import ApplicationServices

/// Service for interacting with macOS Accessibility API
final class AccessibilityService {
    static let shared = AccessibilityService()
    
    private init() {}
    
    // MARK: - Permission Check
    
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
    
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        if hasAccessibilityPermission {
            return true
        }

        guard prompt else {
            return false
        }

        return requestAccessibilityPermission()
    }
    
    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Active Application
    
    func getActiveApplication() -> RunningApplication? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        return RunningApplication(
            bundleIdentifier: frontApp.bundleIdentifier ?? "unknown",
            localizedName: frontApp.localizedName ?? "Unknown",
            processIdentifier: frontApp.processIdentifier,
            isActive: frontApp.isActive
        )
    }
    
    // MARK: - Window Information
    
    func getActiveWindowInfo() -> WindowInfo? {
        guard ensureAccessibilityPermission(prompt: false),
              let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        // Get focused window
        guard let window = copyAttributeValue(appElement, attribute: kAXFocusedWindowAttribute as CFString) else {
            return nil
        }
        
        let windowElement = window as! AXUIElement
        
        // Get window title
        let windowTitle = copyAttributeValue(windowElement, attribute: kAXTitleAttribute as CFString) as? String
        
        // Get window position
        var windowPosition = CGPoint.zero
        if let positionValue = copyAttributeValue(windowElement, attribute: kAXPositionAttribute as CFString) {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &windowPosition)
        }
        
        // Get window size
        var windowSize = CGSize.zero
        if let sizeValue = copyAttributeValue(windowElement, attribute: kAXSizeAttribute as CFString) {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &windowSize)
        }
        
        // Get document path if available
        let documentPath = copyAttributeValue(windowElement, attribute: kAXDocumentAttribute as CFString) as? String
        
        return WindowInfo(
            title: windowTitle,
            position: windowPosition,
            size: windowSize,
            documentPath: documentPath
        )
    }
    
    // MARK: - Selected Text
    
    func getSelectedText() -> String? {
        getSelectedText(withTimeout: 0.25)
    }

    func getSelectedText(withTimeout timeout: TimeInterval) -> String? {
        guard ensureAccessibilityPermission(prompt: false),
              let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        // Get focused UI element
        guard let element = copyAttributeValue(appElement, attribute: kAXFocusedUIElementAttribute as CFString, timeout: timeout) else {
            return nil
        }
        
        let uiElement = element as! AXUIElement
        
        // Get selected text
        guard let selectedText = copyAttributeValue(uiElement, attribute: kAXSelectedTextAttribute as CFString, timeout: timeout),
              let text = selectedText as? String,
              !text.isEmpty else {
            return nil
        }
        
        return text
    }
    
    // MARK: - Text Content
    
    func getTextContent() -> String? {
        getTextContent(withTimeout: 0.25)
    }

    func getTextContent(withTimeout timeout: TimeInterval) -> String? {
        guard ensureAccessibilityPermission(prompt: false),
              let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        // Get focused UI element
        guard let element = copyAttributeValue(appElement, attribute: kAXFocusedUIElementAttribute as CFString, timeout: timeout) else {
            return nil
        }
        
        let uiElement = element as! AXUIElement
        
        // Get full text value
        guard let textValue = copyAttributeValue(uiElement, attribute: kAXValueAttribute as CFString, timeout: timeout),
              let text = textValue as? String else {
            return nil
        }
        
        return text
    }
    
    // MARK: - UI Element Role
    
    func getFocusedElementRole() -> String? {
        guard ensureAccessibilityPermission(prompt: false),
              let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        guard let element = copyAttributeValue(appElement, attribute: kAXFocusedUIElementAttribute as CFString) else {
            return nil
        }
        
        let uiElement = element as! AXUIElement
        
        guard let role = copyAttributeValue(uiElement, attribute: kAXRoleAttribute as CFString),
              let roleString = role as? String else {
            return nil
        }
        
        return roleString
    }

    private func copyAttributeValue(
        _ element: AXUIElement,
        attribute: CFString,
        timeout: TimeInterval = 0.25
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            let status = AXUIElementCopyAttributeValue(element, attribute, &value)
            if status != .success {
                value = nil
            }
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + timeout)
        if result == .timedOut {
            return nil
        }

        return value
    }
}

// MARK: - Supporting Types

struct RunningApplication {
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: pid_t
    let isActive: Bool
}

struct WindowInfo {
    let title: String?
    let position: CGPoint
    let size: CGSize
    let documentPath: String?
    
    var fileName: String? {
        guard let path = documentPath else { return nil }
        return (path as NSString).lastPathComponent
    }
    
    var fileExtension: String? {
        guard let path = documentPath else { return nil }
        return (path as NSString).pathExtension.lowercased()
    }
}
