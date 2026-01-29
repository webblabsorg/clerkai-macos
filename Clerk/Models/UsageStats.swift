import Foundation

struct UsageStats: Codable, Equatable {
    let userId: String
    let period: UsagePeriod
    let runsUsed: Int
    let runsLimit: Int?
    let tokensUsed: Int
    let tokensLimit: Int?
    let storageUsedBytes: Int64
    let storageLimitBytes: Int64?
    let lastRunAt: Date?
    let topTools: [ToolUsage]
    let dailyUsage: [DailyUsage]
    
    var runsRemaining: Int? {
        guard let limit = runsLimit else { return nil }
        return max(0, limit - runsUsed)
    }
    
    var usagePercentage: Double {
        guard let limit = runsLimit, limit > 0 else { return 0 }
        return Double(runsUsed) / Double(limit)
    }
    
    var storagePercentage: Double {
        guard let limit = storageLimitBytes, limit > 0 else { return 0 }
        return Double(storageUsedBytes) / Double(limit)
    }
}

struct ToolUsage: Codable, Equatable, Identifiable {
    var id: String { toolId }
    let toolId: String
    let toolName: String
    let runCount: Int
    let lastUsedAt: Date
}

struct DailyUsage: Codable, Equatable, Identifiable {
    var id: String { date }
    let date: String // YYYY-MM-DD
    let runs: Int
    let tokens: Int
}

enum UsagePeriod: String, Codable {
    case daily
    case weekly
    case monthly
    case yearly
}

extension UsageStats {
    static let preview = UsageStats(
        userId: "user_preview",
        period: .monthly,
        runsUsed: 45,
        runsLimit: nil,
        tokensUsed: 125000,
        tokensLimit: nil,
        storageUsedBytes: 524_288_000, // 500 MB
        storageLimitBytes: 1_073_741_824, // 1 GB
        lastRunAt: Date(),
        topTools: [
            ToolUsage(toolId: "contract_risk_analyzer", toolName: "Contract Risk Analyzer", runCount: 15, lastUsedAt: Date()),
            ToolUsage(toolId: "document_summarizer", toolName: "Document Summarizer", runCount: 12, lastUsedAt: Date()),
            ToolUsage(toolId: "legal_email_drafter", toolName: "Legal Email Drafter", runCount: 8, lastUsedAt: Date())
        ],
        dailyUsage: []
    )
}
