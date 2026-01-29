import XCTest
@testable import Clerk

final class ContextDetectionTests: XCTestCase {
    
    var documentAnalyzer: DocumentAnalyzer!
    
    override func setUp() {
        super.setUp()
        documentAnalyzer = DocumentAnalyzer.shared
    }
    
    // MARK: - Document Type Detection Tests
    
    func testContractDetection() {
        let contractText = """
        This Agreement is entered into between Party A and Party B.
        WHEREAS the parties wish to establish terms and conditions...
        The effective date shall be January 1, 2026.
        Indemnification: Party A shall indemnify and hold harmless...
        """
        
        let docType = documentAnalyzer.detectDocumentType(from: contractText)
        XCTAssertEqual(docType, .contract)
    }
    
    func testBriefDetection() {
        let briefText = """
        IN THE UNITED STATES DISTRICT COURT
        Plaintiff v. Defendant
        MOTION FOR SUMMARY JUDGMENT
        The plaintiff respectfully moves this Court for summary judgment...
        """
        
        let docType = documentAnalyzer.detectDocumentType(from: briefText)
        XCTAssertEqual(docType, .brief)
    }
    
    func testEmailDetection() {
        let emailText = """
        Dear Mr. Smith,
        
        Thank you for your email regarding the contract review.
        Please find attached the revised agreement.
        
        Best regards,
        Jane Doe
        """
        
        let docType = documentAnalyzer.detectDocumentType(from: emailText)
        XCTAssertEqual(docType, .email)
    }
    
    func testFileNameDetection() {
        XCTAssertEqual(documentAnalyzer.detectDocumentType(fromFileName: "NDA_Agreement.docx"), .contract)
        XCTAssertEqual(documentAnalyzer.detectDocumentType(fromFileName: "Motion_to_Dismiss.pdf"), .brief)
        XCTAssertEqual(documentAnalyzer.detectDocumentType(fromFileName: "Legal_Memo.doc"), .memo)
        XCTAssertEqual(documentAnalyzer.detectDocumentType(fromFileName: "random_file.txt"), .unknown)
    }
    
    // MARK: - Legal Term Detection Tests
    
    func testLegalTermDetection() {
        let text = "The force majeure clause provides protection. The indemnification section is broad."
        
        let terms = documentAnalyzer.detectLegalTerms(in: text)
        
        XCTAssertTrue(terms.contains { $0.term == "Force Majeure" })
        XCTAssertTrue(terms.contains { $0.term == "Indemnification" })
    }
    
    // MARK: - Risk Indicator Detection Tests
    
    func testHighRiskIndicatorDetection() {
        let text = "The contractor shall have unlimited liability for all damages."
        
        let indicators = documentAnalyzer.detectRiskIndicators(in: text)
        
        XCTAssertFalse(indicators.isEmpty)
        XCTAssertTrue(indicators.contains { $0.severity == .high })
    }
    
    func testMediumRiskIndicatorDetection() {
        let text = "The vendor shall use reasonable efforts to deliver on time."
        
        let indicators = documentAnalyzer.detectRiskIndicators(in: text)
        
        XCTAssertTrue(indicators.contains { $0.severity == .medium })
    }
    
    // MARK: - Summary Generation Tests
    
    func testQuickSummaryGeneration() {
        let longText = """
        This is the first sentence of the document. This is the second sentence with more details.
        This is the third sentence providing additional context. This is the fourth sentence.
        This is the fifth sentence. This is the sixth sentence.
        """
        
        let summary = documentAnalyzer.generateQuickSummary(of: longText, maxSentences: 3)
        
        XCTAssertFalse(summary.isEmpty)
        XCTAssertLessThan(summary.count, longText.count)
    }
    
    // MARK: - App Classification Tests
    
    func testAppClassification() {
        let appMonitor = AppMonitorService.shared
        
        // Test classification logic
        let classification = appMonitor.classifyActiveApp()
        XCTAssertNotNil(classification)
    }
    
    // MARK: - Source App Tests
    
    func testSourceAppSuggestedCategories() {
        let wordApp = SourceApp.microsoftWord
        let categories = wordApp.suggestedCategories
        
        XCTAssertFalse(categories.isEmpty)
        XCTAssertTrue(categories.contains(.documentDrafting))
    }
    
    func testDocumentTypeSuggestedTools() {
        let contract = DocumentType.contract
        let tools = contract.suggestedTools
        
        XCTAssertFalse(tools.isEmpty)
        XCTAssertTrue(tools.contains("contract_risk_analyzer"))
    }
}
