import SwiftUI

/// SwiftUI view for rendering markdown content
struct MarkdownView: View {
    let content: String
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(parseBlocks(), id: \.id) { block in
                    renderBlock(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Parsing
    
    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = content.components(separatedBy: .newlines)
        var currentList: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Flush list if we're not continuing one
            if !trimmed.hasPrefix("- ") && !trimmed.hasPrefix("* ") && !currentList.isEmpty {
                blocks.append(MarkdownBlock(type: .list, content: currentList.joined(separator: "\n")))
                currentList = []
            }
            
            if trimmed.hasPrefix("## ") {
                blocks.append(MarkdownBlock(type: .heading2, content: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("### ") {
                blocks.append(MarkdownBlock(type: .heading3, content: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(MarkdownBlock(type: .heading1, content: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                currentList.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("```") {
                // Code block handling would go here
                continue
            } else if trimmed.hasPrefix("> ") {
                blocks.append(MarkdownBlock(type: .blockquote, content: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") {
                blocks.append(MarkdownBlock(type: .divider, content: ""))
            } else if !trimmed.isEmpty {
                blocks.append(MarkdownBlock(type: .paragraph, content: trimmed))
            }
        }
        
        // Flush remaining list
        if !currentList.isEmpty {
            blocks.append(MarkdownBlock(type: .list, content: currentList.joined(separator: "\n")))
        }
        
        return blocks
    }
    
    // MARK: - Rendering
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .heading1:
            Text(block.content)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                .padding(.top, 16)
                .padding(.bottom, 8)
            
        case .heading2:
            VStack(alignment: .leading, spacing: 4) {
                Text(block.content)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                
                Rectangle()
                    .fill(ThemeColors.accentGold)
                    .frame(height: 2)
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
            
        case .heading3:
            Text(block.content)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                .padding(.top, 8)
                .padding(.bottom, 2)
            
        case .paragraph:
            renderInlineText(block.content)
                .padding(.vertical, 2)
            
        case .list:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(block.content.components(separatedBy: "\n"), id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(ThemeColors.accentGold)
                        renderInlineText(item)
                    }
                }
            }
            .padding(.vertical, 4)
            
        case .blockquote:
            HStack(spacing: 12) {
                Rectangle()
                    .fill(ThemeColors.accentGold)
                    .frame(width: 3)
                
                Text(block.content)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundColor(ThemeColors.textColor(for: appState.currentTheme).opacity(0.8))
            }
            .padding(.vertical, 8)
            
        case .divider:
            Divider()
                .background(ThemeColors.textColor(for: appState.currentTheme).opacity(0.2))
                .padding(.vertical, 8)
            
        case .code:
            Text(block.content)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.textColor(for: appState.currentTheme).opacity(0.05))
                )
        }
    }
    
    @ViewBuilder
    private func renderInlineText(_ text: String) -> some View {
        // Simple inline formatting
        let formatted = parseInlineFormatting(text)
        
        Text(formatted)
            .font(.system(size: 14))
            .foregroundColor(ThemeColors.textColor(for: appState.currentTheme))
    }
    
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Bold: **text**
        if let boldRange = text.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
            let boldText = String(text[boldRange]).replacingOccurrences(of: "**", with: "")
            if let attrRange = result.range(of: String(text[boldRange])) {
                result.replaceSubrange(attrRange, with: AttributedString(boldText))
            }
        }
        
        return result
    }
}

// MARK: - Markdown Block

struct MarkdownBlock: Identifiable {
    let id = UUID()
    let type: MarkdownBlockType
    let content: String
}

enum MarkdownBlockType {
    case heading1
    case heading2
    case heading3
    case paragraph
    case list
    case blockquote
    case code
    case divider
}

#Preview {
    MarkdownView(content: """
    # Main Heading
    
    ## Risk Analysis
    
    This is a paragraph with some **bold text** and regular text.
    
    ### High Risk Items
    
    - First risk item
    - Second risk item
    - Third risk item
    
    > This is a blockquote with important information.
    
    ---
    
    ## Recommendations
    
    Here are some recommendations for the contract.
    """)
    .environmentObject(AppState.shared)
    .padding()
    .frame(width: 400, height: 600)
}
