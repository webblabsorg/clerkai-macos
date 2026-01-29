import Foundation
import Combine

/// Service for managing tool execution history
final class HistoryService {
    static let shared = HistoryService()
    
    @Published private(set) var executions: [ToolExecution] = []
    @Published private(set) var favorites: [ToolExecution] = []
    
    private let maxHistoryCount = 100
    private let historyKey = "toolExecutionHistory"
    private let favoritesKey = "toolExecutionFavorites"
    
    private init() {
        loadHistory()
    }
    
    // MARK: - History Management
    
    func addExecution(_ execution: ToolExecution) {
        executions.insert(execution, at: 0)
        
        // Trim to max count
        if executions.count > maxHistoryCount {
            executions = Array(executions.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    func removeExecution(_ execution: ToolExecution) {
        executions.removeAll { $0.id == execution.id }
        saveHistory()
    }
    
    func clearHistory() {
        executions.removeAll()
        saveHistory()
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(_ execution: ToolExecution) {
        if isFavorite(execution) {
            favorites.removeAll { $0.id == execution.id }
        } else {
            favorites.insert(execution, at: 0)
        }
        saveFavorites()
    }
    
    func isFavorite(_ execution: ToolExecution) -> Bool {
        favorites.contains { $0.id == execution.id }
    }
    
    // MARK: - Filtering
    
    func executions(for toolId: String) -> [ToolExecution] {
        executions.filter { $0.toolId == toolId }
    }
    
    func executions(inCategory category: ToolCategory) -> [ToolExecution] {
        let toolIds = ToolService.shared.categories[category]?.map { $0.id } ?? []
        return executions.filter { toolIds.contains($0.toolId) }
    }
    
    func executions(from startDate: Date, to endDate: Date) -> [ToolExecution] {
        executions.filter { execution in
            execution.startedAt >= startDate && execution.startedAt <= endDate
        }
    }
    
    func recentExecutions(limit: Int = 10) -> [ToolExecution] {
        Array(executions.prefix(limit))
    }
    
    func successfulExecutions() -> [ToolExecution] {
        executions.filter { $0.status == .completed }
    }
    
    func failedExecutions() -> [ToolExecution] {
        executions.filter { $0.status == .failed }
    }
    
    // MARK: - Search
    
    func search(query: String) -> [ToolExecution] {
        let lowercased = query.lowercased()
        
        return executions.filter { execution in
            execution.toolName.lowercased().contains(lowercased) ||
            execution.output?.content.lowercased().contains(lowercased) == true ||
            execution.input.values.contains { $0.lowercased().contains(lowercased) }
        }
    }
    
    // MARK: - Statistics
    
    func getStatistics() -> HistoryStatistics {
        let total = executions.count
        let successful = executions.filter { $0.status == .completed }.count
        let failed = executions.filter { $0.status == .failed }.count
        
        let totalDuration = executions.compactMap { $0.durationMs }.reduce(0, +)
        let avgDuration = total > 0 ? totalDuration / total : 0
        
        let totalTokens = executions.compactMap { $0.tokensUsed }.reduce(0, +)
        
        // Most used tools
        var toolCounts: [String: Int] = [:]
        for execution in executions {
            toolCounts[execution.toolId, default: 0] += 1
        }
        let topTools = toolCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        return HistoryStatistics(
            totalExecutions: total,
            successfulExecutions: successful,
            failedExecutions: failed,
            averageDurationMs: avgDuration,
            totalTokensUsed: totalTokens,
            topToolIds: Array(topTools)
        )
    }
    
    // MARK: - Persistence
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ToolExecution].self, from: data) {
            executions = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([ToolExecution].self, from: data) {
            favorites = decoded
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(executions) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}

// MARK: - Statistics

struct HistoryStatistics {
    let totalExecutions: Int
    let successfulExecutions: Int
    let failedExecutions: Int
    let averageDurationMs: Int
    let totalTokensUsed: Int
    let topToolIds: [String]
    
    var successRate: Double {
        guard totalExecutions > 0 else { return 0 }
        return Double(successfulExecutions) / Double(totalExecutions)
    }
}
