import Foundation

/// Google Gemini API provider
final class GoogleProvider: AIProvider {
    let name = "Google"
    
    let models: [AIModel] = [
        .geminiFlash
    ]
    
    private let apiKey: String
    private let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
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
        
        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return result.candidates.first?.content.parts.first?.text ?? ""
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
                    
                    var buffer = ""
                    
                    for try await line in bytes.lines {
                        buffer += line
                        
                        // Gemini streams JSON objects
                        if let data = buffer.data(using: .utf8),
                           let event = try? JSONDecoder().decode(GeminiStreamEvent.self, from: data) {
                            if let text = event.candidates?.first?.content.parts.first?.text {
                                continuation.yield(text)
                            }
                            buffer = ""
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
        let endpoint = stream ? "streamGenerateContent" : "generateContent"
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("models/\(model.id):\(endpoint)"), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var contents: [[String: Any]] = []
        
        if let systemPrompt = options.systemPrompt {
            contents.append([
                "role": "user",
                "parts": [["text": systemPrompt]]
            ])
            contents.append([
                "role": "model",
                "parts": [["text": "Understood. I will follow these instructions."]]
            ])
        }
        
        contents.append([
            "role": "user",
            "parts": [["text": prompt]]
        ])
        
        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": options.maxTokens,
                "temperature": options.temperature,
                "topP": options.topP
            ]
        ]
        
        if !options.stopSequences.isEmpty {
            var config = body["generationConfig"] as! [String: Any]
            config["stopSequences"] = options.stopSequences
            body["generationConfig"] = config
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

struct GeminiResponse: Decodable {
    let candidates: [Candidate]
    
    struct Candidate: Decodable {
        let content: Content
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case content
            case finishReason = "finishReason"
        }
    }
    
    struct Content: Decodable {
        let parts: [Part]
        let role: String
    }
    
    struct Part: Decodable {
        let text: String
    }
}

struct GeminiStreamEvent: Decodable {
    let candidates: [GeminiResponse.Candidate]?
}
