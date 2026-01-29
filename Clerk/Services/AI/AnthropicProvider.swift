import Foundation

/// Anthropic Claude API provider
final class AnthropicProvider: AIProvider {
    let name = "Anthropic"
    
    let models: [AIModel] = [
        .claudeHaiku,
        .claudeSonnet,
        .claudeOpus
    ]
    
    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let session: URLSession
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Completion
    
    func complete(prompt: String, model: AIModel, options: CompletionOptions) async throws -> String {
        let request = try buildRequest(prompt: prompt, model: model, options: options, stream: false)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIProviderError.httpError(httpResponse.statusCode, parseError(data))
        }
        
        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return result.content.first?.text ?? ""
    }
    
    // MARK: - Streaming
    
    func stream(prompt: String, model: AIModel, options: CompletionOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(prompt: prompt, model: model, options: options, stream: true)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw AIProviderError.invalidResponse
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                break
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) {
                                if let delta = event.delta?.text {
                                    continuation.yield(delta)
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Request Building
    
    private func buildRequest(prompt: String, model: AIModel, options: CompletionOptions, stream: Bool) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": options.maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        if let systemPrompt = options.systemPrompt {
            body["system"] = systemPrompt
        }
        
        if stream {
            body["stream"] = true
        }
        
        if options.temperature != 0.7 {
            body["temperature"] = options.temperature
        }
        
        if options.topP != 1.0 {
            body["top_p"] = options.topP
        }
        
        if !options.stopSequences.isEmpty {
            body["stop_sequences"] = options.stopSequences
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func parseError(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return "Unknown error"
    }
}

// MARK: - Response Types

struct AnthropicResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: Usage?
    
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
    
    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

struct AnthropicStreamEvent: Decodable {
    let type: String
    let delta: Delta?
    
    struct Delta: Decodable {
        let type: String?
        let text: String?
    }
}

// MARK: - Errors

enum AIProviderError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case rateLimited
    case invalidAPIKey
    case modelNotAvailable
    case contextTooLong
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI provider"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .invalidAPIKey:
            return "Invalid API key"
        case .modelNotAvailable:
            return "Model not available"
        case .contextTooLong:
            return "Input too long for model context"
        }
    }
}
