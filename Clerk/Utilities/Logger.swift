import Foundation
import os.log

/// Centralized logging utility
final class Logger {
    static let shared = Logger()
    
    private let subsystem = "com.clerk.legal"
    
    private lazy var generalLog = OSLog(subsystem: subsystem, category: "general")
    private lazy var networkLog = OSLog(subsystem: subsystem, category: "network")
    private lazy var uiLog = OSLog(subsystem: subsystem, category: "ui")
    private lazy var aiLog = OSLog(subsystem: subsystem, category: "ai")
    private lazy var contextLog = OSLog(subsystem: subsystem, category: "context")
    private lazy var authLog = OSLog(subsystem: subsystem, category: "auth")
    
    private init() {}
    
    // MARK: - Log Levels
    
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func error(_ error: Error, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(error.localizedDescription, level: .error, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        let osLog = osLog(for: category)
        let osLogType = osLogType(for: level)
        
        os_log("%{public}@", log: osLog, type: osLogType, logMessage)
        
        #if DEBUG
        let emoji = emoji(for: level)
        print("\(emoji) [\(category.rawValue.uppercased())] \(logMessage)")
        #endif
    }
    
    private func osLog(for category: LogCategory) -> OSLog {
        switch category {
        case .general: return generalLog
        case .network: return networkLog
        case .ui: return uiLog
        case .ai: return aiLog
        case .context: return contextLog
        case .auth: return authLog
        case .storage: return generalLog
        }
    }
    
    private func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
    
    private func emoji(for level: LogLevel) -> String {
        switch level {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// MARK: - Log Level

enum LogLevel {
    case debug
    case info
    case warning
    case error
}

// MARK: - Log Category

enum LogCategory: String {
    case general
    case network
    case ui
    case ai
    case context
    case auth
    case storage
}

// MARK: - Global Convenience Functions

func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}

func logError(_ error: Error, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(error, category: category, file: file, function: function, line: line)
}
