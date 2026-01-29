import Foundation
import AppKit

/// Formats AI output for display and export
final class OutputFormatter {
    static let shared = OutputFormatter()
    
    private init() {}
    
    // MARK: - Markdown to Attributed String
    
    func attributedString(from markdown: String, theme: AppTheme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let textColor = theme == .light || theme == .cream ? NSColor.black : NSColor.white
        let accentColor = NSColor(hex: "#C9A227") ?? NSColor.orange
        
        let baseFont = NSFont.systemFont(ofSize: 14)
        let headingFont = NSFont.boldSystemFont(ofSize: 18)
        let subheadingFont = NSFont.boldSystemFont(ofSize: 16)
        let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        
        let lines = markdown.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("## ") {
                // H2 heading
                let text = String(trimmed.dropFirst(3))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: headingFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
                
            } else if trimmed.hasPrefix("### ") {
                // H3 heading
                let text = String(trimmed.dropFirst(4))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: subheadingFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
                
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                // Bullet point
                let text = String(trimmed.dropFirst(2))
                let bulletAttrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: accentColor
                ]
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: "• ", attributes: bulletAttrs))
                result.append(NSAttributedString(string: text + "\n", attributes: textAttrs))
                
            } else if trimmed.hasPrefix("```") {
                // Code block marker (skip)
                continue
                
            } else if trimmed.hasPrefix("`") && trimmed.hasSuffix("`") {
                // Inline code
                let text = String(trimmed.dropFirst().dropLast())
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: codeFont,
                    .foregroundColor: textColor,
                    .backgroundColor: NSColor.gray.withAlphaComponent(0.2)
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
                
            } else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
                // Bold text
                let text = String(trimmed.dropFirst(2).dropLast(2))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
                
            } else {
                // Regular text
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: line + "\n", attributes: attrs))
            }
        }
        
        return result
    }
    
    // MARK: - Export Formats
    
    func exportAsPlainText(_ output: ToolOutput) -> String {
        // Strip markdown formatting
        var text = output.content
        
        // Remove markdown headers
        text = text.replacingOccurrences(of: "## ", with: "")
        text = text.replacingOccurrences(of: "### ", with: "")
        text = text.replacingOccurrences(of: "# ", with: "")
        
        // Remove bold/italic markers
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "*", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        
        return text
    }
    
    func exportAsHTML(_ output: ToolOutput, title: String) -> String {
        let content = markdownToHTML(output.content)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(title)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 800px;
                    margin: 40px auto;
                    padding: 20px;
                    line-height: 1.6;
                    color: #333;
                }
                h1, h2, h3 { color: #0A0A0A; }
                h2 { border-bottom: 2px solid #C9A227; padding-bottom: 8px; }
                ul { padding-left: 20px; }
                li { margin-bottom: 8px; }
                code {
                    background: #f4f4f4;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                }
                .risk-high { color: #dc3545; font-weight: bold; }
                .risk-medium { color: #ffc107; font-weight: bold; }
                .risk-low { color: #28a745; }
                .footer {
                    margin-top: 40px;
                    padding-top: 20px;
                    border-top: 1px solid #ddd;
                    font-size: 12px;
                    color: #666;
                }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            \(content)
            <div class="footer">
                Generated by Clerk Legal AI on \(Date().formattedLong)
            </div>
        </body>
        </html>
        """
    }
    
    private func markdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // Headers
        html = html.replacingOccurrences(of: "### ", with: "<h3>")
        html = html.replacingOccurrences(of: "## ", with: "<h2>")
        html = html.replacingOccurrences(of: "# ", with: "<h1>")
        
        // Close headers at end of line
        let lines = html.components(separatedBy: .newlines)
        html = lines.map { line in
            var result = line
            if result.hasPrefix("<h1>") { result += "</h1>" }
            if result.hasPrefix("<h2>") { result += "</h2>" }
            if result.hasPrefix("<h3>") { result += "</h3>" }
            if result.hasPrefix("- ") || result.hasPrefix("* ") {
                result = "<li>" + String(result.dropFirst(2)) + "</li>"
            }
            return result
        }.joined(separator: "\n")
        
        // Bold
        html = html.replacingOccurrences(of: "**", with: "<strong>", options: [], range: nil)
        
        // Code
        html = html.replacingOccurrences(of: "`", with: "<code>", options: [], range: nil)
        
        // Paragraphs
        html = "<p>" + html.replacingOccurrences(of: "\n\n", with: "</p><p>") + "</p>"
        
        return html
    }
    
    // MARK: - Risk Formatting
    
    func formatRiskScore(_ score: Double) -> (text: String, color: NSColor) {
        let text = String(format: "%.1f/10", score)
        
        let color: NSColor
        switch score {
        case 0..<3:
            color = NSColor.systemGreen
        case 3..<5:
            color = NSColor.systemBlue
        case 5..<7:
            color = NSColor.systemYellow
        case 7..<9:
            color = NSColor.systemOrange
        default:
            color = NSColor.systemRed
        }
        
        return (text, color)
    }
    
    func riskLabel(for score: Double) -> String {
        switch score {
        case 0..<3: return "Low Risk"
        case 3..<5: return "Moderate Risk"
        case 5..<7: return "Elevated Risk"
        case 7..<9: return "High Risk"
        default: return "Critical Risk"
        }
    }
}

// MARK: - NSColor Extension

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
