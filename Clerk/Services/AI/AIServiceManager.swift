import Foundation
import Combine

/// Central manager for AI services and model selection
final class AIServiceManager {
    static let shared = AIServiceManager()
    
    @Published private(set) var currentProvider: AIProviderType = .anthropic
    @Published private(set) var currentModel: AIModel = .claudeHaiku
    @Published private(set) var isAvailable = false
    
    private var providers: [AIProviderType: AIProvider] = [:]
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration
    
    private func loadConfiguration() {
        // In production, API keys are fetched from backend
        // For now, check if configured
        Task {
            await checkAvailability()
        }
    }
    
    func configure(anthropicKey: String?, openaiKey: String?, googleKey: String?) {
        if let key = anthropicKey, !key.isEmpty {
            providers[.anthropic] = AnthropicProvider(apiKey: key)
        }
        
        if let key = openaiKey, !key.isEmpty {
            providers[.openai] = OpenAIProvider(apiKey: key)
        }
        
        if let key = googleKey, !key.isEmpty {
            providers[.google] = GoogleProvider(apiKey: key)
        }
        
        isAvailable = !providers.isEmpty
    }
    
    private func checkAvailability() async {
        // Check with backend for API availability
        do {
            let config: AIConfiguration = try await apiClient.request(endpoint: "ai/config")
            
            await MainActor.run {
                configure(
                    anthropicKey: config.anthropicEnabled ? "backend-managed" : nil,
                    openaiKey: config.openaiEnabled ? "backend-managed" : nil,
                    googleKey: config.googleEnabled ? "backend-managed" : nil
                )
            }
        } catch {
            logError(error, category: .ai)
        }
    }
    
    // MARK: - Model Selection
    
    func selectModel(for tier: SubscriptionTier) -> AIModel {
        switch tier {
        case .free:
            return .geminiFlash
        case .pro:
            return .claudeHaiku
        case .plus, .team:
            return .claudeSonnet
        case .enterprise:
            return .claudeOpus
        }
    }
    
    func setModel(_ model: AIModel) {
        currentModel = model
        currentProvider = model.provider
    }
    
    func getAvailableModels(for tier: SubscriptionTier) -> [AIModel] {
        let allModels: [AIModel] = [.geminiFlash, .claudeHaiku, .claudeSonnet, .claudeOpus, .gpt4o]
        
        return allModels.filter { model in
            switch tier {
            case .free:
                return model.tier == .free
            case .pro:
                return model.tier == .free || model.tier == .pro
            case .plus, .team:
                return model.tier != .enterprise
            case .enterprise:
                return true
            }
        }
    }
    
    // MARK: - Completion
    
    func complete(prompt: String, options: CompletionOptions = .default) async throws -> String {
        guard let provider = providers[currentProvider] else {
            // Fall back to backend API
            return try await backendComplete(prompt: prompt, options: options)
        }
        
        return try await provider.complete(prompt: prompt, model: currentModel, options: options)
    }
    
    func stream(prompt: String, options: CompletionOptions = .default) -> AsyncThrowingStream<String, Error> {
        guard let provider = providers[currentProvider] else {
            // Fall back to backend streaming
            return backendStream(prompt: prompt, options: options)
        }
        
        return provider.stream(prompt: prompt, model: currentModel, options: options)
    }
    
    // MARK: - Backend Fallback
    
    private func backendComplete(prompt: String, options: CompletionOptions) async throws -> String {
        let request = BackendCompletionRequest(
            prompt: prompt,
            model: currentModel.id,
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            systemPrompt: options.systemPrompt
        )
        
        let response: BackendCompletionResponse = try await apiClient.request(
            endpoint: "ai/complete",
            method: .post,
            body: request
        )
        
        return response.content
    }
    
    private func backendStream(prompt: String, options: CompletionOptions) -> AsyncThrowingStream<String, Error> {
        apiClient.streamRequest(
            endpoint: "ai/stream",
            method: .post,
            body: BackendCompletionRequest(
                prompt: prompt,
                model: currentModel.id,
                maxTokens: options.maxTokens,
                temperature: options.temperature,
                systemPrompt: options.systemPrompt
            )
        )
    }
}

// MARK: - Configuration Types

struct AIConfiguration: Decodable {
    let anthropicEnabled: Bool
    let openaiEnabled: Bool
    let googleEnabled: Bool
    let defaultModel: String?
}

struct BackendCompletionRequest: Encodable {
    let prompt: String
    let model: String
    let maxTokens: Int
    let temperature: Double
    let systemPrompt: String?
}

struct BackendCompletionResponse: Decodable {
    let content: String
    let model: String
    let tokensUsed: Int
}
