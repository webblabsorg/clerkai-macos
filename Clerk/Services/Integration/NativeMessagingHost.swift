import Foundation
import AppKit

/// Native Messaging Host for Chrome/Firefox/Edge browser extensions
/// 
/// Chrome Native Messaging Protocol:
/// - Messages are JSON with a 4-byte length prefix (little-endian uint32)
/// - Communication is via stdin/stdout
/// - Host manifest must be registered in browser-specific location
/// 
/// This class handles the stdio communication; it should be run as a separate
/// helper executable or via XPC for sandboxed apps.
final class NativeMessagingHost {
    
    private let inputHandle: FileHandle
    private let outputHandle: FileHandle
    private var isRunning = false
    
    init(input: FileHandle = .standardInput, output: FileHandle = .standardOutput) {
        self.inputHandle = input
        self.outputHandle = output
    }
    
    // MARK: - Message Loop
    
    func run() {
        isRunning = true
        
        while isRunning {
            guard let message = readMessage() else {
                break
            }
            
            let response = handleMessage(message)
            writeMessage(response)
        }
    }
    
    func stop() {
        isRunning = false
    }
    
    // MARK: - Message I/O
    
    private func readMessage() -> BrowserExtensionRequest? {
        // Read 4-byte length prefix
        let lengthData = inputHandle.readData(ofLength: 4)
        guard lengthData.count == 4 else {
            return nil
        }
        
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard length > 0, length < 1_000_000 else {
            return nil
        }
        
        // Read message body
        let messageData = inputHandle.readData(ofLength: Int(length))
        guard messageData.count == Int(length) else {
            return nil
        }
        
        return try? JSONDecoder().decode(BrowserExtensionRequest.self, from: messageData)
    }
    
    private func writeMessage(_ response: BrowserExtensionResponse) {
        guard let data = try? JSONEncoder().encode(response) else {
            return
        }
        
        // Write 4-byte length prefix
        var length = UInt32(data.count)
        let lengthData = Data(bytes: &length, count: 4)
        
        outputHandle.write(lengthData)
        outputHandle.write(data)
    }
    
    // MARK: - Message Handling
    
    private func handleMessage(_ request: BrowserExtensionRequest) -> BrowserExtensionResponse {
        switch request {
        case .ping:
            return BrowserExtensionResponse(
                success: true,
                data: .pong,
                error: nil
            )
            
        case .getContext:
            return handleGetContext()
            
        case .getPageContent(let url):
            return handleGetPageContent(url: url)
            
        case .getSelection:
            return handleGetSelection()
            
        case .executeAction(let action):
            return handleExecuteAction(action)
        }
    }
    
    private func handleGetContext() -> BrowserExtensionResponse {
        // In a real implementation, this would query the ContextEngine
        // For now, return a stub response
        let context = BrowserContextData(
            url: "",
            title: "",
            domain: "",
            pageType: "unknown",
            hasSelection: false,
            suggestedTools: ["document_summarizer", "legal_research_assistant"]
        )
        
        return BrowserExtensionResponse(
            success: true,
            data: .context(context),
            error: nil
        )
    }
    
    private func handleGetPageContent(url: String) -> BrowserExtensionResponse {
        // Stub: real implementation would receive content from extension
        let content = PageContentData(
            url: url,
            title: "",
            textContent: "",
            selectedText: nil,
            metadata: nil
        )
        
        return BrowserExtensionResponse(
            success: true,
            data: .pageContent(content),
            error: nil
        )
    }
    
    private func handleGetSelection() -> BrowserExtensionResponse {
        // Try to get selection via AccessibilityService
        if let selection = AccessibilityService.shared.getSelectedText() {
            return BrowserExtensionResponse(
                success: true,
                data: .selection(selection),
                error: nil
            )
        }
        
        return BrowserExtensionResponse(
            success: false,
            data: nil,
            error: "No selection available"
        )
    }
    
    private func handleExecuteAction(_ action: BrowserAction) -> BrowserExtensionResponse {
        let result: ActionResultData
        
        switch action {
        case .insertText(let text):
            SelectionService.shared.pasteText(text)
            result = ActionResultData(actionId: UUID().uuidString, success: true, message: nil)
            
        case .copyToClipboard(let text):
            ClipboardService.shared.setText(text)
            result = ActionResultData(actionId: UUID().uuidString, success: true, message: nil)
            
        case .openUrl(let url):
            if let nsUrl = URL(string: url) {
                NSWorkspace.shared.open(nsUrl)
                result = ActionResultData(actionId: UUID().uuidString, success: true, message: nil)
            } else {
                result = ActionResultData(actionId: UUID().uuidString, success: false, message: "Invalid URL")
            }
            
        case .highlightText:
            // Not implemented for native app
            result = ActionResultData(actionId: UUID().uuidString, success: false, message: "Highlight not supported")
        }
        
        return BrowserExtensionResponse(
            success: result.success,
            data: .actionResult(result),
            error: result.success ? nil : result.message
        )
    }
}

// MARK: - Host Manifest

/// Generates the native messaging host manifest for browser registration
struct NativeMessagingManifest {
    
    static func chromeManifest(hostPath: String, extensionIds: [String]) -> [String: Any] {
        [
            "name": "com.clerk.legal.native",
            "description": "Clerk Legal AI Native Messaging Host",
            "path": hostPath,
            "type": "stdio",
            "allowed_origins": extensionIds.map { "chrome-extension://\($0)/" }
        ]
    }
    
    static func firefoxManifest(hostPath: String, extensionIds: [String]) -> [String: Any] {
        [
            "name": "com.clerk.legal.native",
            "description": "Clerk Legal AI Native Messaging Host",
            "path": hostPath,
            "type": "stdio",
            "allowed_extensions": extensionIds
        ]
    }
    
    /// Installation paths for host manifests
    static var chromeManifestPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.clerk.legal.native.json"
    }
    
    static var firefoxManifestPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Mozilla/NativeMessagingHosts/com.clerk.legal.native.json"
    }
    
    static var edgeManifestPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.clerk.legal.native.json"
    }
}
