import Foundation
import Combine
import AppKit

/// ViewModel for tool execution
@MainActor
final class ToolExecutionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var tool: Tool?
    @Published var inputValues: [String: String] = [:]
    @Published var isExecuting = false
    @Published var progress: Double = 0
    @Published var streamedContent = ""
    @Published var result: ToolExecution?
    @Published var error: Error?
    
    // MARK: - Services
    
    private let aiService = AIService.shared
    private let toolService = ToolService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var canExecute: Bool {
        guard let tool = tool else { return false }
        
        if let schema = tool.inputSchema {
            for field in schema.fields where field.isRequired {
                if inputValues[field.id]?.isEmpty ?? true {
                    return false
                }
            }
        }
        
        return true
    }
    
    var hasResult: Bool {
        result != nil
    }
    
    var riskScore: Double? {
        result?.output?.riskScore
    }
    
    var highlights: [OutputHighlight]? {
        result?.output?.highlights
    }
    
    // MARK: - Actions
    
    func setTool(_ tool: Tool) {
        self.tool = tool
        self.inputValues = [:]
        self.result = nil
        self.error = nil
        self.streamedContent = ""
        
        // Set default values
        if let schema = tool.inputSchema {
            for field in schema.fields {
                if let defaultValue = field.defaultValue {
                    inputValues[field.id] = defaultValue
                }
            }
        }
    }
    
    func execute() async {
        guard let tool = tool, canExecute else { return }
        
        isExecuting = true
        progress = 0
        streamedContent = ""
        error = nil
        
        do {
            let execution = try await aiService.executeTool(
                toolId: tool.id,
                input: inputValues,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.progress = progress
                    }
                },
                onStream: { [weak self] content in
                    Task { @MainActor in
                        self?.streamedContent += content
                    }
                }
            )
            
            result = execution
            toolService.addToRecent(tool)
            
            logInfo("Tool execution completed: \(tool.id)", category: .ai)
        } catch {
            self.error = error
            ErrorHandler.shared.handle(error, context: .ai)
        }
        
        isExecuting = false
    }
    
    func reset() {
        result = nil
        error = nil
        progress = 0
        streamedContent = ""
    }
    
    func copyResult() {
        guard let content = result?.output?.content else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    func exportResult(format: ExportFormat) async throws -> URL {
        guard let content = result?.output?.content else {
            throw ClerkError.exportFailed
        }
        
        let fileName = "\(tool?.name ?? "result")_\(Date().iso8601)"
        let tempDir = FileManager.default.temporaryDirectory
        
        switch format {
        case .text:
            let url = tempDir.appendingPathComponent("\(fileName).txt")
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
            
        case .markdown:
            let url = tempDir.appendingPathComponent("\(fileName).md")
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
            
        case .pdf:
            // TODO: Implement PDF export
            throw ClerkError.exportFailed
            
        case .word:
            // TODO: Implement Word export
            throw ClerkError.exportFailed
        }
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case text = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case word = "docx"
    
    var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .word: return "Word Document"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .markdown: return "doc.richtext"
        case .pdf: return "doc.fill"
        case .word: return "doc"
        }
    }
}
