import Foundation

/// Protocol for browser extension communication
/// 
/// Architecture Overview:
/// - Safari: Uses Safari App Extension with native messaging via NSXPCConnection
/// - Chrome/Edge/Brave: Uses Native Messaging Host protocol (JSON over stdio)
/// - Firefox: Uses Native Messaging Host protocol (same as Chrome)
/// 
/// The extension sends messages to the native app, which responds with context/actions.
/// This file defines the message protocol; actual extensions are separate projects.

// MARK: - Message Protocol

/// Messages sent from browser extension to native app
enum BrowserExtensionRequest: Codable {
    case getContext
    case getPageContent(url: String)
    case getSelection
    case executeAction(action: BrowserAction)
    case ping
    
    enum CodingKeys: String, CodingKey {
        case type
        case url
        case action
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "getContext":
            self = .getContext
        case "getPageContent":
            let url = try container.decode(String.self, forKey: .url)
            self = .getPageContent(url: url)
        case "getSelection":
            self = .getSelection
        case "executeAction":
            let action = try container.decode(BrowserAction.self, forKey: .action)
            self = .executeAction(action: action)
        case "ping":
            self = .ping
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .getContext:
            try container.encode("getContext", forKey: .type)
        case .getPageContent(let url):
            try container.encode("getPageContent", forKey: .type)
            try container.encode(url, forKey: .url)
        case .getSelection:
            try container.encode("getSelection", forKey: .type)
        case .executeAction(let action):
            try container.encode("executeAction", forKey: .type)
            try container.encode(action, forKey: .action)
        case .ping:
            try container.encode("ping", forKey: .type)
        }
    }
}

/// Messages sent from native app to browser extension
struct BrowserExtensionResponse: Codable {
    let success: Bool
    let data: ResponseData?
    let error: String?
    
    enum ResponseData: Codable {
        case context(BrowserContextData)
        case pageContent(PageContentData)
        case selection(String)
        case actionResult(ActionResultData)
        case pong
        
        enum CodingKeys: String, CodingKey {
            case type
            case context
            case pageContent
            case selection
            case actionResult
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "context":
                let ctx = try container.decode(BrowserContextData.self, forKey: .context)
                self = .context(ctx)
            case "pageContent":
                let content = try container.decode(PageContentData.self, forKey: .pageContent)
                self = .pageContent(content)
            case "selection":
                let sel = try container.decode(String.self, forKey: .selection)
                self = .selection(sel)
            case "actionResult":
                let result = try container.decode(ActionResultData.self, forKey: .actionResult)
                self = .actionResult(result)
            case "pong":
                self = .pong
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .context(let ctx):
                try container.encode("context", forKey: .type)
                try container.encode(ctx, forKey: .context)
            case .pageContent(let content):
                try container.encode("pageContent", forKey: .type)
                try container.encode(content, forKey: .pageContent)
            case .selection(let sel):
                try container.encode("selection", forKey: .type)
                try container.encode(sel, forKey: .selection)
            case .actionResult(let result):
                try container.encode("actionResult", forKey: .type)
                try container.encode(result, forKey: .actionResult)
            case .pong:
                try container.encode("pong", forKey: .type)
            }
        }
    }
}

// MARK: - Data Types

struct BrowserContextData: Codable {
    let url: String
    let title: String
    let domain: String
    let pageType: String
    let hasSelection: Bool
    let suggestedTools: [String]
}

struct PageContentData: Codable {
    let url: String
    let title: String
    let textContent: String
    let selectedText: String?
    let metadata: [String: String]?
}

struct ActionResultData: Codable {
    let actionId: String
    let success: Bool
    let message: String?
}

enum BrowserAction: Codable {
    case insertText(text: String)
    case copyToClipboard(text: String)
    case openUrl(url: String)
    case highlightText(ranges: [TextRange])
    
    struct TextRange: Codable {
        let start: Int
        let end: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case url
        case ranges
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "insertText":
            let text = try container.decode(String.self, forKey: .text)
            self = .insertText(text: text)
        case "copyToClipboard":
            let text = try container.decode(String.self, forKey: .text)
            self = .copyToClipboard(text: text)
        case "openUrl":
            let url = try container.decode(String.self, forKey: .url)
            self = .openUrl(url: url)
        case "highlightText":
            let ranges = try container.decode([TextRange].self, forKey: .ranges)
            self = .highlightText(ranges: ranges)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .insertText(let text):
            try container.encode("insertText", forKey: .type)
            try container.encode(text, forKey: .text)
        case .copyToClipboard(let text):
            try container.encode("copyToClipboard", forKey: .type)
            try container.encode(text, forKey: .text)
        case .openUrl(let url):
            try container.encode("openUrl", forKey: .type)
            try container.encode(url, forKey: .url)
        case .highlightText(let ranges):
            try container.encode("highlightText", forKey: .type)
            try container.encode(ranges, forKey: .ranges)
        }
    }
}
