import Foundation
import Combine

/// Engine for executing legal AI tools
final class ToolExecutionEngine {
    static let shared = ToolExecutionEngine()
    
    @Published private(set) var isExecuting = false
    @Published private(set) var currentExecution: ToolExecution?
    @Published private(set) var executionHistory: [ToolExecution] = []
    
    private let aiManager = AIServiceManager.shared
    private let toolService = ToolService.shared
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Execution
    
    func execute(
        tool: Tool,
        input: [String: String],
        onProgress: @escaping (Double) -> Void,
        onStream: @escaping (String) -> Void
    ) async throws -> ToolExecution {
        isExecuting = true
        
        let executionId = UUID().uuidString
        let startTime = Date()
        
        // Create initial execution record
        var execution = ToolExecution(
            id: executionId,
            toolId: tool.id,
            toolName: tool.name,
            userId: AppState.shared.currentUser?.id ?? "anonymous",
            status: .running,
            input: input,
            output: nil,
            startedAt: startTime,
            completedAt: nil,
            durationMs: nil,
            tokensUsed: nil,
            error: nil
        )
        
        currentExecution = execution
        
        do {
            // Build prompt from tool and input
            let prompt = buildPrompt(for: tool, input: input)
            let systemPrompt = buildSystemPrompt(for: tool)
            
            // Get appropriate model for user's tier
            let tier = AppState.shared.subscriptionTier
            let model = aiManager.selectModel(for: tier)
            aiManager.setModel(model)
            
            // Execute with streaming
            var fullContent = ""
            var progress: Double = 0
            
            let options = CompletionOptions(
                maxTokens: model.maxTokens,
                temperature: 0.5,
                systemPrompt: systemPrompt
            )
            
            // Stream the response
            let stream = aiManager.stream(prompt: prompt, options: options)
            
            for try await chunk in stream {
                fullContent += chunk
                onStream(chunk)
                
                // Estimate progress based on content length
                progress = min(0.95, Double(fullContent.count) / 2000.0)
                onProgress(progress)
            }
            
            onProgress(1.0)
            
            // Parse output
            let output = parseOutput(fullContent, for: tool)
            
            // Complete execution
            let endTime = Date()
            execution = ToolExecution(
                id: executionId,
                toolId: tool.id,
                toolName: tool.name,
                userId: execution.userId,
                status: .completed,
                input: input,
                output: output,
                startedAt: startTime,
                completedAt: endTime,
                durationMs: Int(endTime.timeIntervalSince(startTime) * 1000),
                tokensUsed: estimateTokens(fullContent),
                error: nil
            )
            
            // Save to history
            addToHistory(execution)
            
            // Update tool service
            toolService.addToRecent(tool)
            
            logInfo("Tool execution completed: \(tool.id)", category: .ai)
            
        } catch {
            // Handle error
            execution = ToolExecution(
                id: executionId,
                toolId: tool.id,
                toolName: tool.name,
                userId: execution.userId,
                status: .failed,
                input: input,
                output: nil,
                startedAt: startTime,
                completedAt: Date(),
                durationMs: nil,
                tokensUsed: nil,
                error: ExecutionError(
                    code: "execution_failed",
                    message: error.localizedDescription,
                    details: nil,
                    isRetryable: true
                )
            )
            
            logError(error, category: .ai)
            throw error
        }
        
        currentExecution = execution
        isExecuting = false
        
        return execution
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(for tool: Tool, input: [String: String]) -> String {
        var prompt = ""
        
        // Add input fields
        for (key, value) in input {
            if !value.isEmpty {
                prompt += "\(key.replacingOccurrences(of: "_", with: " ").capitalized):\n\(value)\n\n"
            }
        }
        
        return prompt
    }
    
    private func buildSystemPrompt(for tool: Tool) -> String {
        let basePrompt = """
        You are Clerk, an AI legal assistant. You are executing the "\(tool.name)" tool.
        
        Tool Description: \(tool.description)
        
        Instructions:
        - Provide accurate, professional legal analysis
        - Use clear, structured formatting with headers and bullet points
        - Cite specific sections, clauses, or references when applicable
        - Highlight risks, issues, or important findings clearly
        - Be thorough but concise
        - Use markdown formatting for better readability
        
        """
        
        // Add tool-specific instructions
        let toolInstructions = getToolInstructions(for: tool.id)
        
        return basePrompt + toolInstructions
    }
    
    private func getToolInstructions(for toolId: String) -> String {
        switch toolId {
        case "contract_risk_analyzer":
            return """
            Analyze the contract for:
            1. High-risk clauses (unlimited liability, broad indemnification, etc.)
            2. Medium-risk clauses (vague terms, one-sided provisions)
            3. Missing standard protections
            4. Unusual or concerning language
            
            Format your response with:
            - Overall Risk Score (1-10)
            - High Risk Items (with section references)
            - Medium Risk Items (with section references)
            - Low Risk Items
            - Recommendations
            """
            
        case "document_summarizer":
            return """
            Provide a comprehensive summary including:
            1. Document type and purpose
            2. Key parties involved
            3. Main terms and conditions
            4. Important dates and deadlines
            5. Key obligations for each party
            6. Notable provisions or unusual terms
            """
            
        case "case_law_finder":
            return """
            Research and provide:
            1. Relevant case citations with full case names
            2. Brief summary of each case's holding
            3. How each case applies to the legal issue
            4. Jurisdiction and court level
            5. Whether the case is still good law
            """
            
        case "legal_email_drafter":
            return """
            Draft a professional legal email that:
            1. Uses appropriate salutation and closing
            2. Maintains professional tone
            3. Is clear and concise
            4. Includes all necessary information
            5. Avoids legal jargon where possible
            """
            
        default:
            return "Provide thorough, accurate analysis based on the input provided."
        }
    }
    
    // MARK: - Output Parsing
    
    private func parseOutput(_ content: String, for tool: Tool) -> ToolOutput {
        var riskScore: Double?
        var highlights: [OutputHighlight] = []
        
        // Parse risk score if present
        if let scoreMatch = content.range(of: #"Risk Score[:\s]*(\d+(?:\.\d+)?)"#, options: .regularExpression) {
            let scoreText = String(content[scoreMatch])
            if let number = scoreText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().first {
                riskScore = Double(String(number))
            }
        }
        
        // Parse high risk items
        let highRiskPattern = #"(?:High Risk|HIGH RISK)[:\s]*\n((?:[-•*]\s*.+\n?)+)"#
        if let match = content.range(of: highRiskPattern, options: .regularExpression) {
            let items = parseListItems(String(content[match]))
            for (index, item) in items.enumerated() {
                highlights.append(OutputHighlight(
                    id: "high_\(index)",
                    type: .risk,
                    title: item,
                    description: "",
                    reference: nil,
                    severity: .high
                ))
            }
        }
        
        // Parse medium risk items
        let mediumRiskPattern = #"(?:Medium Risk|MEDIUM RISK)[:\s]*\n((?:[-•*]\s*.+\n?)+)"#
        if let match = content.range(of: mediumRiskPattern, options: .regularExpression) {
            let items = parseListItems(String(content[match]))
            for (index, item) in items.enumerated() {
                highlights.append(OutputHighlight(
                    id: "medium_\(index)",
                    type: .risk,
                    title: item,
                    description: "",
                    reference: nil,
                    severity: .medium
                ))
            }
        }
        
        return ToolOutput(
            content: content,
            format: .markdown,
            riskScore: riskScore,
            highlights: highlights.isEmpty ? nil : highlights,
            actions: [
                OutputAction(id: "copy", label: "Copy", type: .copy, payload: nil),
                OutputAction(id: "export", label: "Export", type: .export, payload: "pdf")
            ],
            metadata: nil
        )
    }
    
    private func parseListItems(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("-") || $0.hasPrefix("•") || $0.hasPrefix("*") }
            .map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        text.count / 4
    }
    
    // MARK: - History
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "executionHistory"),
           let history = try? JSONDecoder().decode([ToolExecution].self, from: data) {
            executionHistory = history
        }
    }
    
    private func addToHistory(_ execution: ToolExecution) {
        executionHistory.insert(execution, at: 0)
        
        // Keep last 50 executions
        if executionHistory.count > 50 {
            executionHistory = Array(executionHistory.prefix(50))
        }
        
        // Save to disk
        if let data = try? JSONEncoder().encode(executionHistory) {
            UserDefaults.standard.set(data, forKey: "executionHistory")
        }
    }
    
    func clearHistory() {
        executionHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "executionHistory")
    }
}
