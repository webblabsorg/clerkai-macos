import Foundation

/// OpenAI API provider
final class OpenAIProvider: AIProvider {
    let name = "OpenAI"
    
    let models: [AIModel] = [
        .gpt4o
    ]
    
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1")!
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
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
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
                               let event = try? JSONDecoder().decode(OpenAIStreamEvent.self, from: data) {
                                if let content = event.choices.first?.delta.content {
                                    continuation.yield(content)
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
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var messages: [[String: String]] = []
        
        if let systemPrompt = options.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        messages.append(["role": "user", "content": prompt])
        
        var body: [String: Any] = [
            "model": model.id,
            "messages": messages,
            "max_tokens": options.maxTokens,
            "temperature": options.temperature,
            "top_p": options.topP
        ]
        
        if stream {
            body["stream"] = true
        }
        
        if !options.stopSequences.isEmpty {
            body["stop"] = options.stopSequences
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

struct OpenAIResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Decodable {
        let role: String
        let content: String
    }
    
    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct OpenAIStreamEvent: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Decodable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Decodable {
        let role: String?
        let content: String?
    }
}
