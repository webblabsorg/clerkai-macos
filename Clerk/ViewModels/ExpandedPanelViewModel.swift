import Foundation
import Combine

/// ViewModel for the expanded panel view
@MainActor
final class ExpandedPanelViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchText = ""
    @Published var searchResults: [Tool] = []
    @Published var suggestedTools: [Tool] = []
    @Published var recentTools: [Tool] = []
    @Published var categories: [ToolCategory] = ToolCategory.allCases
    @Published var selectedCategory: ToolCategory?
    @Published var categoryTools: [Tool] = []
    @Published var isLoading = false
    
    // MARK: - Services
    
    private let toolService = ToolService.shared
    private let contextService = ContextDetectionService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Search debouncing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query)
            }
            .store(in: &cancellables)
        
        // Context changes
        contextService.$currentContext
            .receive(on: RunLoop.main)
            .sink { [weak self] context in
                self?.updateSuggestions(for: context)
            }
            .store(in: &cancellables)
        
        // Tool service updates
        toolService.$recentTools
            .receive(on: RunLoop.main)
            .assign(to: &$recentTools)
    }
    
    private func loadInitialData() {
        Task {
            isLoading = true
            
            do {
                try await toolService.fetchAllTools()
                updateSuggestions(for: contextService.currentContext)
            } catch {
                ErrorHandler.shared.handle(error, context: .network)
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Search
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchResults = toolService.fuzzySearch(query: query)
    }
    
    var isSearching: Bool {
        !searchText.isEmpty
    }
    
    // MARK: - Suggestions
    
    private func updateSuggestions(for context: DetectedContext?) {
        suggestedTools = toolService.suggestedTools(for: context)
    }
    
    // MARK: - Categories
    
    func selectCategory(_ category: ToolCategory) {
        selectedCategory = category
        
        Task {
            do {
                categoryTools = try await toolService.fetchToolsByCategory(category)
            } catch {
                categoryTools = toolService.categories[category] ?? []
            }
        }
    }
    
    func clearCategory() {
        selectedCategory = nil
        categoryTools = []
    }
    
    // MARK: - Tool Actions
    
    func selectTool(_ tool: Tool) {
        AppState.shared.setTool(tool)
    }
    
    func toggleFavorite(_ tool: Tool) {
        toolService.toggleFavorite(tool)
    }
    
    func isFavorite(_ tool: Tool) -> Bool {
        toolService.isFavorite(tool)
    }
}
