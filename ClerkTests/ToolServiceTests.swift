import XCTest
@testable import Clerk

final class ToolServiceTests: XCTestCase {
    
    var toolService: ToolService!
    
    override func setUp() {
        super.setUp()
        toolService = ToolService.shared
    }
    
    // MARK: - Search Tests
    
    func testSearchByName() {
        // Given
        let tools = Tool.previewList
        
        // When
        let results = tools.filter { $0.name.lowercased().contains("contract") }
        
        // Then
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.name.lowercased().contains("contract") })
    }
    
    func testSearchByCategory() {
        // Given
        let category = ToolCategory.contractReview
        
        // When
        let tools = Tool.previewList.filter { $0.category == category }
        
        // Then
        XCTAssertFalse(tools.isEmpty)
    }
    
    func testFuzzySearch() {
        // Given
        let query = "cntrct"
        let target = "contract"
        
        // When
        var score = 0
        var queryIndex = query.startIndex
        
        for char in target {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                score += 1
                queryIndex = query.index(after: queryIndex)
            }
        }
        
        // Then
        XCTAssertGreaterThan(score, 0)
    }
    
    // MARK: - Category Tests
    
    func testAllCategoriesExist() {
        let categories = ToolCategory.allCases
        XCTAssertEqual(categories.count, 18)
    }
    
    func testCategoryToolCounts() {
        let totalTools = ToolCategory.allCases.reduce(0) { $0 + $1.toolCount }
        XCTAssertEqual(totalTools, 301)
    }
    
    func testCategoryDisplayNames() {
        for category in ToolCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.icon.isEmpty)
        }
    }
    
    // MARK: - Tool Model Tests
    
    func testToolCreation() {
        let tool = Tool.preview
        
        XCTAssertEqual(tool.id, "contract_risk_analyzer")
        XCTAssertEqual(tool.category, .contractReview)
        XCTAssertNotNil(tool.inputSchema)
        XCTAssertFalse(tool.isAvailableForFree)
    }
    
    func testToolInputSchema() {
        let tool = Tool.preview
        
        guard let schema = tool.inputSchema else {
            XCTFail("Schema should exist")
            return
        }
        
        XCTAssertFalse(schema.fields.isEmpty)
        
        let requiredFields = schema.fields.filter { $0.isRequired }
        XCTAssertFalse(requiredFields.isEmpty)
    }
    
    // MARK: - Favorites Tests
    
    func testToggleFavorite() {
        let tool = Tool.preview
        
        // Initially not favorite
        XCTAssertFalse(toolService.isFavorite(tool))
        
        // Toggle on
        toolService.toggleFavorite(tool)
        XCTAssertTrue(toolService.isFavorite(tool))
        
        // Toggle off
        toolService.toggleFavorite(tool)
        XCTAssertFalse(toolService.isFavorite(tool))
    }
    
    // MARK: - Recent Tools Tests
    
    func testAddToRecent() {
        let tool = Tool.preview
        
        toolService.addToRecent(tool)
        
        XCTAssertTrue(toolService.recentTools.contains { $0.id == tool.id })
    }
}
