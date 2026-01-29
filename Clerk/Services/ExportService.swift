import Foundation
import AppKit
import PDFKit

/// Service for exporting tool results
final class ExportService {
    static let shared = ExportService()
    
    private let formatter = OutputFormatter.shared
    
    private init() {}
    
    // MARK: - Export Methods
    
    func exportAsText(_ execution: ToolExecution) throws -> URL {
        guard let output = execution.output else {
            throw ExportError.noContent
        }
        
        let content = formatter.exportAsPlainText(output)
        let fileName = sanitizeFileName("\(execution.toolName)_\(execution.id).txt")
        
        return try saveToFile(content: content, fileName: fileName)
    }
    
    func exportAsMarkdown(_ execution: ToolExecution) throws -> URL {
        guard let output = execution.output else {
            throw ExportError.noContent
        }
        
        let header = """
        # \(execution.toolName)
        
        **Generated:** \(execution.startedAt.formattedLong)
        **Duration:** \(execution.durationMs ?? 0)ms
        
        ---
        
        """
        
        let content = header + output.content
        let fileName = sanitizeFileName("\(execution.toolName)_\(execution.id).md")
        
        return try saveToFile(content: content, fileName: fileName)
    }
    
    func exportAsHTML(_ execution: ToolExecution) throws -> URL {
        guard let output = execution.output else {
            throw ExportError.noContent
        }
        
        let html = formatter.exportAsHTML(output, title: execution.toolName)
        let fileName = sanitizeFileName("\(execution.toolName)_\(execution.id).html")
        
        return try saveToFile(content: html, fileName: fileName)
    }
    
    func exportAsPDF(_ execution: ToolExecution) throws -> URL {
        guard let output = execution.output else {
            throw ExportError.noContent
        }
        
        // First create HTML
        let html = formatter.exportAsHTML(output, title: execution.toolName)
        
        // Convert HTML to PDF using WebKit
        let pdfData = try htmlToPDF(html)
        
        let fileName = sanitizeFileName("\(execution.toolName)_\(execution.id).pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try pdfData.write(to: url)
        
        return url
    }
    
    // MARK: - Batch Export
    
    func exportMultiple(_ executions: [ToolExecution], format: ExportFormat) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clerk_export_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        for execution in executions {
            do {
                let url: URL
                switch format {
                case .text:
                    url = try exportAsText(execution)
                case .markdown:
                    url = try exportAsMarkdown(execution)
                case .pdf:
                    url = try exportAsPDF(execution)
                case .word:
                    url = try exportAsMarkdown(execution) // Fallback to markdown
                }
                
                let destURL = tempDir.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: destURL)
            } catch {
                logWarning("Failed to export \(execution.toolName): \(error)", category: .general)
            }
        }
        
        // Create zip archive
        let zipURL = tempDir.deletingLastPathComponent()
            .appendingPathComponent("clerk_export.zip")
        
        try createZipArchive(from: tempDir, to: zipURL)
        
        return zipURL
    }
    
    // MARK: - Share
    
    func share(_ execution: ToolExecution, format: ExportFormat, from view: NSView) {
        do {
            let url: URL
            switch format {
            case .text:
                url = try exportAsText(execution)
            case .markdown:
                url = try exportAsMarkdown(execution)
            case .pdf:
                url = try exportAsPDF(execution)
            case .word:
                url = try exportAsMarkdown(execution)
            }
            
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } catch {
            ErrorHandler.shared.handle(error, context: .general, showAlert: true)
        }
    }
    
    // MARK: - Save Dialog
    
    func saveWithDialog(_ execution: ToolExecution, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        
        let fileName = sanitizeFileName(execution.toolName)
        
        switch format {
        case .text:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "\(fileName).txt"
        case .markdown:
            panel.allowedContentTypes = [.text]
            panel.nameFieldStringValue = "\(fileName).md"
        case .pdf:
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "\(fileName).pdf"
        case .word:
            panel.allowedContentTypes = [.text]
            panel.nameFieldStringValue = "\(fileName).md"
        }
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                let tempURL: URL
                switch format {
                case .text:
                    tempURL = try self.exportAsText(execution)
                case .markdown:
                    tempURL = try self.exportAsMarkdown(execution)
                case .pdf:
                    tempURL = try self.exportAsPDF(execution)
                case .word:
                    tempURL = try self.exportAsMarkdown(execution)
                }
                
                try FileManager.default.copyItem(at: tempURL, to: url)
                
                // Open in Finder
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                ErrorHandler.shared.handle(error, context: .general, showAlert: true)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func saveToFile(content: String, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    private func htmlToPDF(_ html: String) throws -> Data {
        // Create a simple PDF from HTML using print operation
        // This is a simplified version - production would use WebKit
        
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 612, height: 792) // Letter size
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        
        // For now, create a basic PDF with the text content
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw ExportError.pdfCreationFailed
        }
        
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.pdfCreationFailed
        }
        
        context.beginPDFPage(nil)
        
        // Draw text (simplified - production would render HTML properly)
        let textRect = CGRect(x: 72, y: 72, width: 468, height: 648)
        let plainText = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: plainText, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        CTFrameDraw(frame, context)
        
        context.endPDFPage()
        context.closePDF()
        
        return pdfData as Data
    }
    
    private func createZipArchive(from sourceDir: URL, to destURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", destURL.path, "."]
        process.currentDirectoryURL = sourceDir
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ExportError.zipCreationFailed
        }
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case noContent
    case pdfCreationFailed
    case zipCreationFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .noContent:
            return "No content to export"
        case .pdfCreationFailed:
            return "Failed to create PDF"
        case .zipCreationFailed:
            return "Failed to create archive"
        case .fileWriteFailed:
            return "Failed to write file"
        }
    }
}
