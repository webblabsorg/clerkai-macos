import SwiftUI

struct ToolExecutionView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputValues: [String: String] = [:]
    @State private var streamedOutput: String = ""
    @State private var executionResult: ToolExecution?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
                .background(ThemeColors.accentGold.opacity(0.3))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.isExecutingTool {
                        executingView
                    } else if let result = executionResult {
                        resultsView(result)
                    } else {
                        inputFormView
                    }
                }
                .padding()
            }
            
            // Action bar
            if !appState.isExecutingTool {
                actionBar
            }
        }
        .frame(width: 450, height: 650)
        .background(ThemeColors.backgroundColor(for: appState.currentTheme))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                appState.clearTool()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if let tool = appState.currentTool {
                Text(tool.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear.frame(width: 14, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Input Form
    
    private var inputFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let tool = appState.currentTool {
                // Tool description
                Text(tool.description)
                    .font(.system(size: 13))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                
                // Input fields
                if let schema = tool.inputSchema {
                    ForEach(schema.fields) { field in
                        InputFieldView(field: field, value: binding(for: field.id))
                    }
                } else {
                    // Default text input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                        
                        TextEditor(text: binding(for: "input"))
                            .font(.system(size: 13))
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
                                    .stroke(ThemeColors.textColor(for: appState.currentTheme).opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Executing View
    
    private var executingView: some View {
        VStack(spacing: 16) {
            // Progress indicator
            VStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ThemeColors.accentGold)
                
                Text("Analyzing...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                
                ProgressView(value: appState.executionProgress)
                    .progressViewStyle(.linear)
                    .tint(ThemeColors.accentGold)
                    .frame(maxWidth: 200)
                
                Text("\(Int(appState.executionProgress * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            
            // Streaming output
            if !streamedOutput.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RESULTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
                        .tracking(0.5)
                    
                    Text(streamedOutput)
                        .font(.system(size: 13))
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                }
            }
        }
    }
    
    // MARK: - Results View
    
    private func resultsView(_ execution: ToolExecution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Risk score (if applicable)
            if let output = execution.output, let riskScore = output.riskScore {
                riskScoreView(score: riskScore)
            }
            
            // Highlights
            if let output = execution.output, let highlights = output.highlights {
                highlightsView(highlights)
            }
            
            // Main content
            if let output = execution.output {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANALYSIS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
                        .tracking(0.5)
                    
                    Text(output.content)
                        .font(.system(size: 13))
                        .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private func riskScoreView(score: Double) -> some View {
        HStack {
            Text("Risk Score:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            
            Text(String(format: "%.1f/10", score))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(riskColor(for: score))
            
            Image(systemName: riskIcon(for: score))
                .foregroundColor(riskColor(for: score))
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(riskColor(for: score).opacity(0.1))
                .stroke(riskColor(for: score).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func highlightsView(_ highlights: [OutputHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(HighlightSeverity.allCases, id: \.self) { severity in
                let filtered = highlights.filter { $0.severity == severity }
                if !filtered.isEmpty {
                    highlightSection(severity: severity, items: filtered)
                }
            }
        }
    }
    
    private func highlightSection(severity: HighlightSeverity, items: [OutputHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(severityColor(severity))
                    .frame(width: 8, height: 8)
                
                Text("\(severity.rawValue.uppercased()) (\(items.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
            }
            
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(severityColor(severity))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                        
                        if let reference = item.reference {
                            Text(reference)
                                .font(.system(size: 11))
                                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.5))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 12) {
            if executionResult != nil {
                // Result actions
                Button {
                    copyResults()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button {
                    exportResults()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Spacer()
                
                Button {
                    rerun()
                } label: {
                    Label("Re-run", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Spacer()
                
                Button {
                    executeToolAction()
                } label: {
                    Label("Run Analysis", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canExecute)
            }
        }
        .padding()
        .background(ThemeColors.backgroundColor(for: appState.currentTheme))
    }
    
    // MARK: - Helpers
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { inputValues[key] ?? "" },
            set: { inputValues[key] = $0 }
        )
    }
    
    private var canExecute: Bool {
        guard let tool = appState.currentTool else { return false }
        
        if let schema = tool.inputSchema {
            for field in schema.fields where field.isRequired {
                if inputValues[field.id]?.isEmpty ?? true {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func executeToolAction() {
        appState.isExecutingTool = true
        // TODO: Implement actual tool execution via AIService
        
        // Simulate execution
        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    appState.executionProgress = Double(i) / 10.0
                }
            }
            
            await MainActor.run {
                appState.isExecutingTool = false
                executionResult = ToolExecution.preview
            }
        }
    }
    
    private func copyResults() {
        if let content = executionResult?.output?.content {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        }
    }
    
    private func exportResults() {
        // TODO: Implement export
    }
    
    private func rerun() {
        executionResult = nil
        appState.executionProgress = 0
    }
    
    private func riskColor(for score: Double) -> Color {
        switch score {
        case 0..<4: return .green
        case 4..<7: return .yellow
        default: return .red
        }
    }
    
    private func riskIcon(for score: Double) -> String {
        switch score {
        case 0..<4: return "checkmark.circle.fill"
        case 4..<7: return "exclamationmark.triangle.fill"
        default: return "xmark.circle.fill"
        }
    }
    
    private func severityColor(_ severity: HighlightSeverity) -> Color {
        switch severity {
        case .high: return .red
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

// MARK: - HighlightSeverity CaseIterable

extension HighlightSeverity: CaseIterable {
    static var allCases: [HighlightSeverity] = [.high, .medium, .low, .info]
}

// MARK: - Input Field View

struct InputFieldView: View {
    let field: ToolInputField
    @Binding var value: String
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.7))
                
                if field.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            
            switch field.type {
            case .text:
                TextField(field.placeholder ?? "", text: $value)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(inputBackground)
                
            case .textarea:
                TextEditor(text: $value)
                    .font(.system(size: 13))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(inputBackground)
                
            case .select:
                Picker("", selection: $value) {
                    Text("Select...").tag("")
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                
            case .toggle:
                Toggle("", isOn: Binding(
                    get: { value == "true" },
                    set: { value = $0 ? "true" : "false" }
                ))
                .toggleStyle(.switch)
                
            default:
                TextField(field.placeholder ?? "", text: $value)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(inputBackground)
            }
        }
    }
    
    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
            .stroke(ThemeColors.textColor(for: appState.currentTheme).opacity(0.1), lineWidth: 1)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ThemeColors.deepBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ThemeColors.accentGold)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(ThemeColors.accentGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ThemeColors.accentGold, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    ToolExecutionView()
        .environmentObject(AppState.shared)
}
