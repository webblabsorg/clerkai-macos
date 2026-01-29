import Foundation

/// Protocol for AI model providers
protocol AIProvider {
    var name: String { get }
    var models: [AIModel] { get }
    
    func complete(prompt: String, model: AIModel, options: CompletionOptions) async throws -> String
    func stream(prompt: String, model: AIModel, options: CompletionOptions) -> AsyncThrowingStream<String, Error>
}

/// AI Model representation
struct AIModel: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let provider: AIProviderType
    let maxTokens: Int
    let costPer1kInputTokens: Decimal
    let costPer1kOutputTokens: Decimal
    let tier: SubscriptionTier
    
    static let claudeHaiku = AIModel(
        id: "claude-3-haiku-20240307",
        name: "Claude 3 Haiku",
        provider: .anthropic,
        maxTokens: 4096,
        costPer1kInputTokens: 0.00025,
        costPer1kOutputTokens: 0.00125,
        tier: .pro
    )
    
    static let claudeSonnet = AIModel(
        id: "claude-3-5-sonnet-20241022",
        name: "Claude 3.5 Sonnet",
        provider: .anthropic,
        maxTokens: 8192,
        costPer1kInputTokens: 0.003,
        costPer1kOutputTokens: 0.015,
        tier: .plus
    )
    
    static let claudeOpus = AIModel(
        id: "claude-3-opus-20240229",
        name: "Claude 3 Opus",
        provider: .anthropic,
        maxTokens: 16384,
        costPer1kInputTokens: 0.015,
        costPer1kOutputTokens: 0.075,
        tier: .enterprise
    )
    
    static let geminiFlash = AIModel(
        id: "gemini-1.5-flash",
        name: "Gemini 1.5 Flash",
        provider: .google,
        maxTokens: 500,
        costPer1kInputTokens: 0.000075,
        costPer1kOutputTokens: 0.0003,
        tier: .free
    )
    
    static let gpt4o = AIModel(
        id: "gpt-4o",
        name: "GPT-4o",
        provider: .openai,
        maxTokens: 8192,
        costPer1kInputTokens: 0.005,
        costPer1kOutputTokens: 0.015,
        tier: .plus
    )
}

/// AI Provider types
enum AIProviderType: String, Codable {
    case anthropic
    case openai
    case google
    
    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .google: return "Google"
        }
    }
}

/// Completion options
struct CompletionOptions {
    var maxTokens: Int = 4096
    var temperature: Double = 0.7
    var topP: Double = 1.0
    var stopSequences: [String] = []
    var systemPrompt: String?
    
    static let `default` = CompletionOptions()
    
    static let precise = CompletionOptions(
        temperature: 0.3,
        topP: 0.9
    )
    
    static let creative = CompletionOptions(
        temperature: 0.9,
        topP: 1.0
    )
}

/// Message for chat completions
struct ChatMessage: Codable {
    let role: MessageRole
    let content: String
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}
