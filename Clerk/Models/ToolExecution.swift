import Foundation

struct ToolExecution: Codable, Identifiable, Equatable {
    let id: String
    let toolId: String
    let toolName: String
    let userId: String
    let status: ExecutionStatus
    let input: [String: String]
    let output: ToolOutput?
    let startedAt: Date
    let completedAt: Date?
    let durationMs: Int?
    let tokensUsed: Int?
    let error: ExecutionError?
    
    var isComplete: Bool {
        status == .completed || status == .failed
    }
    
    var isRunning: Bool {
        status == .running || status == .streaming
    }
}

enum ExecutionStatus: String, Codable {
    case pending
    case running
    case streaming
    case completed
    case failed
    case cancelled
}

struct ToolOutput: Codable, Equatable {
    let content: String
    let format: OutputFormat
    let riskScore: Double?
    let highlights: [OutputHighlight]?
    let actions: [OutputAction]?
    let metadata: [String: String]?
}

enum OutputFormat: String, Codable {
    case text
    case markdown
    case html
    case json
}

struct OutputHighlight: Codable, Equatable, Identifiable {
    let id: String
    let type: HighlightType
    let title: String
    let description: String
    let reference: String?
    let severity: HighlightSeverity?
}

enum HighlightType: String, Codable {
    case risk
    case issue
    case suggestion
    case citation
    case clause
    case finding
}

enum HighlightSeverity: String, Codable {
    case high
    case medium
    case low
    case info
    
    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "yellow"
        case .low: return "blue"
        case .info: return "gray"
        }
    }
}

struct OutputAction: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let type: ActionType
    let payload: String?
}

enum ActionType: String, Codable {
    case copy
    case export
    case rerun
    case share
    case openLink
    case insertText
}

struct ExecutionError: Codable, Equatable {
    let code: String
    let message: String
    let details: String?
    let isRetryable: Bool
}

// MARK: - Preview Data

extension ToolExecution {
    static let preview = ToolExecution(
        id: "exec_preview",
        toolId: "contract_risk_analyzer",
        toolName: "Contract Risk Analyzer",
        userId: "user_preview",
        status: .completed,
        input: ["contract_text": "Sample contract text..."],
        output: ToolOutput(
            content: "## Risk Analysis\n\nOverall Risk Score: **7.2/10**",
            format: .markdown,
            riskScore: 7.2,
            highlights: [
                OutputHighlight(
                    id: "h1",
                    type: .risk,
                    title: "Unlimited Liability",
                    description: "Section 8.1 contains unlimited liability clause",
                    reference: "§8.1",
                    severity: .high
                ),
                OutputHighlight(
                    id: "h2",
                    type: .risk,
                    title: "No Termination Clause",
                    description: "Contract lacks clear termination provisions",
                    reference: "§12",
                    severity: .high
                )
            ],
            actions: [
                OutputAction(id: "a1", label: "Copy", type: .copy, payload: nil),
                OutputAction(id: "a2", label: "Export PDF", type: .export, payload: "pdf")
            ],
            metadata: nil
        ),
        startedAt: Date().addingTimeInterval(-30),
        completedAt: Date(),
        durationMs: 28500,
        tokensUsed: 1250,
        error: nil
    )
}
