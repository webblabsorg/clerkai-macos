import Foundation
import Combine

/// Service for AI model interactions
final class AIService {
    static let shared = AIService()
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Tool Execution
    
    func executeTool(
        toolId: String,
        input: [String: String],
        onProgress: @escaping (Double) -> Void,
        onStream: @escaping (String) -> Void
    ) async throws -> ToolExecution {
        let request = ToolExecutionRequest(
            toolId: toolId,
            input: input
        )
        
        // Start execution
        let startResponse: ToolExecutionStartResponse = try await apiClient.request(
            endpoint: "tools/\(toolId)/execute",
            method: .post,
            body: request
        )
        
        // Stream results
        var fullContent = ""
        let stream = apiClient.streamRequest(
            endpoint: "tools/executions/\(startResponse.executionId)/stream",
            method: .get
        )
        
        var progress: Double = 0
        for try await chunk in stream {
            if let data = chunk.data(using: .utf8),
               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {
                switch event.type {
                case .progress:
                    progress = event.progress ?? progress
                    onProgress(progress)
                case .content:
                    if let content = event.content {
                        fullContent += content
                        onStream(content)
                    }
                case .complete:
                    break
                case .error:
                    throw AIServiceError.executionFailed(event.error ?? "Unknown error")
                }
            }
        }
        
        // Get final result
        let result: ToolExecution = try await apiClient.request(
            endpoint: "tools/executions/\(startResponse.executionId)"
        )
        
        return result
    }
    
    // MARK: - Quick Actions
    
    func summarize(text: String) async throws -> String {
        let result = try await executeTool(
            toolId: "document_summarizer",
            input: ["text": text],
            onProgress: { _ in },
            onStream: { _ in }
        )
        return result.output?.content ?? ""
    }
    
    func analyzeRisks(contractText: String) async throws -> ToolExecution {
        return try await executeTool(
            toolId: "contract_risk_analyzer",
            input: ["contract_text": contractText],
            onProgress: { _ in },
            onStream: { _ in }
        )
    }
}

// MARK: - Request/Response Models

struct ToolExecutionRequest: Encodable {
    let toolId: String
    let input: [String: String]
}

struct ToolExecutionStartResponse: Decodable {
    let executionId: String
    let status: String
}

struct StreamEvent: Decodable {
    let type: StreamEventType
    let content: String?
    let progress: Double?
    let error: String?
}

enum StreamEventType: String, Decodable {
    case progress
    case content
    case complete
    case error
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case executionFailed(String)
    case invalidInput
    case quotaExceeded
    case modelUnavailable
    
    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .invalidInput:
            return "Invalid input provided"
        case .quotaExceeded:
            return "You've reached your usage limit"
        case .modelUnavailable:
            return "AI model is currently unavailable"
        }
    }
}
