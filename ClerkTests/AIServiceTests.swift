import XCTest
@testable import Clerk

final class AIServiceTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testModelTierSelection() {
        // Free tier gets Gemini Flash
        let freeModel = AIServiceManager.shared.selectModel(for: .free)
        XCTAssertEqual(freeModel.id, AIModel.geminiFlash.id)
        
        // Pro tier gets Claude Haiku
        let proModel = AIServiceManager.shared.selectModel(for: .pro)
        XCTAssertEqual(proModel.id, AIModel.claudeHaiku.id)
        
        // Plus tier gets Claude Sonnet
        let plusModel = AIServiceManager.shared.selectModel(for: .plus)
        XCTAssertEqual(plusModel.id, AIModel.claudeSonnet.id)
        
        // Enterprise tier gets Claude Opus
        let enterpriseModel = AIServiceManager.shared.selectModel(for: .enterprise)
        XCTAssertEqual(enterpriseModel.id, AIModel.claudeOpus.id)
    }
    
    func testAvailableModelsForTier() {
        // Free tier should only have free models
        let freeModels = AIServiceManager.shared.getAvailableModels(for: .free)
        XCTAssertTrue(freeModels.allSatisfy { $0.tier == .free })
        
        // Enterprise should have all models
        let enterpriseModels = AIServiceManager.shared.getAvailableModels(for: .enterprise)
        XCTAssertGreaterThan(enterpriseModels.count, freeModels.count)
    }
    
    // MARK: - Prompt Template Tests
    
    func testPromptTemplateFilling() {
        let template = "Hello {name}, your score is {score}."
        let values = ["name": "John", "score": "95"]
        
        let result = PromptTemplates.fillTemplate(template, with: values)
        
        XCTAssertEqual(result, "Hello John, your score is 95.")
    }
    
    func testGetTemplateForTool() {
        XCTAssertNotNil(PromptTemplates.getTemplate(for: "contract_risk_analyzer"))
        XCTAssertNotNil(PromptTemplates.getTemplate(for: "document_summarizer"))
        XCTAssertNotNil(PromptTemplates.getTemplate(for: "case_law_finder"))
        XCTAssertNil(PromptTemplates.getTemplate(for: "nonexistent_tool"))
    }
    
    // MARK: - Completion Options Tests
    
    func testDefaultCompletionOptions() {
        let options = CompletionOptions.default
        
        XCTAssertEqual(options.maxTokens, 4096)
        XCTAssertEqual(options.temperature, 0.7)
        XCTAssertEqual(options.topP, 1.0)
        XCTAssertTrue(options.stopSequences.isEmpty)
    }
    
    func testPreciseCompletionOptions() {
        let options = CompletionOptions.precise
        
        XCTAssertEqual(options.temperature, 0.3)
        XCTAssertEqual(options.topP, 0.9)
    }
    
    // MARK: - Output Formatting Tests
    
    func testRiskScoreFormatting() {
        let formatter = OutputFormatter.shared
        
        let (lowText, lowColor) = formatter.formatRiskScore(2.5)
        XCTAssertEqual(lowText, "2.5/10")
        XCTAssertEqual(lowColor, .systemGreen)
        
        let (highText, highColor) = formatter.formatRiskScore(8.5)
        XCTAssertEqual(highText, "8.5/10")
        XCTAssertEqual(highColor, .systemRed)
    }
    
    func testRiskLabel() {
        let formatter = OutputFormatter.shared
        
        XCTAssertEqual(formatter.riskLabel(for: 1.0), "Low Risk")
        XCTAssertEqual(formatter.riskLabel(for: 4.0), "Moderate Risk")
        XCTAssertEqual(formatter.riskLabel(for: 6.0), "Elevated Risk")
        XCTAssertEqual(formatter.riskLabel(for: 8.0), "High Risk")
        XCTAssertEqual(formatter.riskLabel(for: 9.5), "Critical Risk")
    }
}
