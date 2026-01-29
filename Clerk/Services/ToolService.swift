import Foundation
import Combine

/// Service for managing tools catalog
final class ToolService {
    static let shared = ToolService()
    
    @Published private(set) var allTools: [Tool] = []
    @Published private(set) var categories: [ToolCategory: [Tool]] = [:]
    @Published private(set) var recentTools: [Tool] = []
    @Published private(set) var favoriteTools: [Tool] = []
    
    private let apiClient = APIClient.shared
    private let defaults = UserDefaultsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadCachedTools()
    }
    
    // MARK: - Fetch Tools
    
    func fetchAllTools() async throws {
        let tools: [Tool] = try await apiClient.request(endpoint: "tools")
        
        await MainActor.run {
            self.allTools = tools
            self.organizeByCategory(tools)
            self.cacheTools(tools)
        }
    }
    
    func fetchToolsByCategory(_ category: ToolCategory) async throws -> [Tool] {
        let tools: [Tool] = try await apiClient.request(
            endpoint: "tools",
            queryItems: [URLQueryItem(name: "category", value: category.rawValue)]
        )
        return tools
    }
    
    func fetchTool(id: String) async throws -> Tool {
        return try await apiClient.request(endpoint: "tools/\(id)")
    }
    
    // MARK: - Search
    
    func search(query: String) -> [Tool] {
        let lowercasedQuery = query.lowercased()
        
        return allTools.filter { tool in
            tool.name.lowercased().contains(lowercasedQuery) ||
            tool.description.lowercased().contains(lowercasedQuery) ||
            tool.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    func fuzzySearch(query: String) -> [Tool] {
        // Simple fuzzy matching
        let lowercasedQuery = query.lowercased()
        
        return allTools
            .map { tool -> (Tool, Int) in
                let score = fuzzyScore(query: lowercasedQuery, target: tool.name.lowercased())
                return (tool, score)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    private func fuzzyScore(query: String, target: String) -> Int {
        var score = 0
        var queryIndex = query.startIndex
        
        for char in target {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                score += 1
                queryIndex = query.index(after: queryIndex)
            }
        }
        
        // Bonus for exact prefix match
        if target.hasPrefix(query) {
            score += query.count * 2
        }
        
        return queryIndex == query.endIndex ? score : 0
    }
    
    // MARK: - Recent Tools
    
    func addToRecent(_ tool: Tool) {
        recentTools.removeAll { $0.id == tool.id }
        recentTools.insert(tool, at: 0)
        
        // Keep only last 10
        if recentTools.count > 10 {
            recentTools = Array(recentTools.prefix(10))
        }
        
        saveRecentTools()
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(_ tool: Tool) {
        if favoriteTools.contains(where: { $0.id == tool.id }) {
            favoriteTools.removeAll { $0.id == tool.id }
        } else {
            favoriteTools.append(tool)
        }
        
        saveFavorites()
    }
    
    func isFavorite(_ tool: Tool) -> Bool {
        favoriteTools.contains { $0.id == tool.id }
    }
    
    // MARK: - Suggestions
    
    func suggestedTools(for context: DetectedContext?) -> [Tool] {
        guard let context = context else {
            // Return popular tools
            return Array(allTools.prefix(4))
        }
        
        var suggested: [Tool] = []
        
        // Add tools based on document type
        if let docType = context.documentType {
            let toolIds = docType.suggestedTools
            suggested.append(contentsOf: allTools.filter { toolIds.contains($0.id) })
        }
        
        // Add tools based on source app categories
        for category in context.sourceApp.suggestedCategories {
            if let categoryTools = categories[category] {
                suggested.append(contentsOf: categoryTools.prefix(2))
            }
        }
        
        // Remove duplicates and limit
        var seen = Set<String>()
        return suggested.filter { tool in
            if seen.contains(tool.id) { return false }
            seen.insert(tool.id)
            return true
        }.prefix(6).map { $0 }
    }
    
    // MARK: - Organization
    
    private func organizeByCategory(_ tools: [Tool]) {
        var organized: [ToolCategory: [Tool]] = [:]
        
        for tool in tools {
            if organized[tool.category] == nil {
                organized[tool.category] = []
            }
            organized[tool.category]?.append(tool)
        }
        
        categories = organized
    }
    
    // MARK: - Caching
    
    private func loadCachedTools() {
        if let cached: [Tool] = defaults.get(.cachedToolCategories) {
            allTools = cached
            organizeByCategory(cached)
        }
        
        if let recent: [Tool] = defaults.get(.cachedRecentTools) {
            recentTools = recent
        }
    }
    
    private func cacheTools(_ tools: [Tool]) {
        defaults.set(tools, for: .cachedToolCategories)
        defaults.setDate(Date(), for: .lastSyncDate)
    }
    
    private func saveRecentTools() {
        defaults.set(recentTools, for: .cachedRecentTools)
    }
    
    private func saveFavorites() {
        // Save to user defaults or sync to server
    }
}
