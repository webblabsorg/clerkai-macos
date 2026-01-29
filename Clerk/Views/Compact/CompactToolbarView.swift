import SwiftUI

struct CompactToolbarView: View {
    @EnvironmentObject var appState: AppState
    
    private let toolbarHeight: CGFloat = 56
    private let toolbarWidth: CGFloat = 320
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar button
            avatarButton
            
            // Quick action buttons
            quickActionButtons
            
            Spacer()
            
            // Expand button
            expandButton
        }
        .padding(.horizontal, 12)
        .frame(width: toolbarWidth, height: toolbarHeight)
        .background(toolbarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
    
    private var avatarButton: some View {
        Button {
            appState.transitionTo(.minimized)
        } label: {
            Circle()
                .fill(ThemeColors.accentGold)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "scale.3d")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ThemeColors.deepBlack)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var quickActionButtons: some View {
        HStack(spacing: 6) {
            ForEach(suggestedActions, id: \.id) { action in
                QuickActionButton(action: action) {
                    executeQuickAction(action)
                }
            }
        }
    }
    
    private var expandButton: some View {
        Button {
            appState.transitionTo(.expanded)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(ThemeColors.accentGold.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var toolbarBackground: some View {
        if #available(macOS 12.0, *) {
            Rectangle()
                .fill(.ultraThinMaterial)
        } else {
            Rectangle()
                .fill(ThemeColors.backgroundColor(for: appState.currentTheme).opacity(0.95))
        }
    }
    
    private var suggestedActions: [QuickAction] {
        // Context-aware suggestions based on detected context
        if let context = appState.detectedContext {
            return QuickAction.forContext(context)
        }
        return QuickAction.defaults
    }
    
    private func executeQuickAction(_ action: QuickAction) {
        // Find the tool and execute
        if let tool = findTool(id: action.toolId) {
            appState.setTool(tool)
        }
    }
    
    private func findTool(id: String) -> Tool? {
        // TODO: Implement tool lookup from ToolService
        Tool.previewList.first { $0.id == id }
    }
}

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
    let id: String
    let label: String
    let icon: String
    let toolId: String
    
    static let defaults: [QuickAction] = [
        QuickAction(id: "summarize", label: "Summarize", icon: "doc.text", toolId: "document_summarizer"),
        QuickAction(id: "risks", label: "Check Risks", icon: "exclamationmark.shield", toolId: "contract_risk_analyzer"),
        QuickAction(id: "draft", label: "Draft", icon: "pencil", toolId: "legal_email_drafter"),
        QuickAction(id: "search", label: "Search", icon: "magnifyingglass", toolId: "case_law_finder")
    ]
    
    static func forContext(_ context: DetectedContext) -> [QuickAction] {
        // Return context-specific actions
        switch context.documentType {
        case .contract:
            return [
                QuickAction(id: "analyze", label: "Analyze", icon: "doc.on.clipboard", toolId: "contract_risk_analyzer"),
                QuickAction(id: "summarize", label: "Summarize", icon: "doc.text", toolId: "contract_summarizer"),
                QuickAction(id: "clauses", label: "Clauses", icon: "list.bullet", toolId: "clause_extractor")
            ]
        case .email:
            return [
                QuickAction(id: "reply", label: "Reply", icon: "arrowshape.turn.up.left", toolId: "email_response_generator"),
                QuickAction(id: "draft", label: "Draft", icon: "pencil", toolId: "legal_email_drafter")
            ]
        default:
            return defaults
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                Text(action.label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ThemeColors.accentGold.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CompactToolbarView()
        .environmentObject(AppState.shared)
        .padding()
        .background(Color.gray.opacity(0.3))
}
