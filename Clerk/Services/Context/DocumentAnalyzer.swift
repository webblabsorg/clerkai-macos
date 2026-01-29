import Foundation
import NaturalLanguage

/// Service for analyzing document content and classifying document types
final class DocumentAnalyzer {
    static let shared = DocumentAnalyzer()
    
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    
    private init() {}
    
    // MARK: - Document Type Detection
    
    func detectDocumentType(from text: String) -> DocumentType {
        let lowercased = text.lowercased()
        
        // Contract indicators
        let contractKeywords = [
            "agreement", "contract", "parties", "whereas", "hereby",
            "terms and conditions", "effective date", "termination",
            "indemnification", "liability", "governing law", "jurisdiction",
            "confidentiality", "non-disclosure", "intellectual property",
            "warranties", "representations", "breach", "remedy"
        ]
        
        let contractScore = calculateKeywordScore(text: lowercased, keywords: contractKeywords)
        if contractScore > 0.3 {
            return .contract
        }
        
        // Legal brief/motion indicators
        let briefKeywords = [
            "plaintiff", "defendant", "court", "motion", "brief",
            "memorandum", "argument", "conclusion", "relief",
            "jurisdiction", "venue", "standing", "precedent",
            "case law", "statute", "ruling", "judgment"
        ]
        
        let briefScore = calculateKeywordScore(text: lowercased, keywords: briefKeywords)
        if briefScore > 0.25 {
            return .brief
        }
        
        // Email indicators
        let emailKeywords = [
            "dear", "sincerely", "regards", "best regards",
            "thank you", "please find attached", "as discussed",
            "following up", "in response to", "re:", "fwd:"
        ]
        
        let emailScore = calculateKeywordScore(text: lowercased, keywords: emailKeywords)
        if emailScore > 0.2 {
            return .email
        }
        
        // Memo indicators
        let memoKeywords = [
            "memorandum", "memo", "to:", "from:", "date:", "re:",
            "subject:", "issue", "analysis", "recommendation"
        ]
        
        let memoScore = calculateKeywordScore(text: lowercased, keywords: memoKeywords)
        if memoScore > 0.25 {
            return .memo
        }
        
        return .unknown
    }
    
    func detectDocumentType(fromFileName fileName: String) -> DocumentType {
        let lowercased = fileName.lowercased()
        
        // Contract patterns
        if lowercased.contains("contract") || lowercased.contains("agreement") ||
           lowercased.contains("nda") || lowercased.contains("msa") ||
           lowercased.contains("sla") || lowercased.contains("terms") {
            return .contract
        }
        
        // Brief/Motion patterns
        if lowercased.contains("brief") || lowercased.contains("motion") ||
           lowercased.contains("pleading") || lowercased.contains("complaint") ||
           lowercased.contains("answer") || lowercased.contains("discovery") {
            return .brief
        }
        
        // Memo patterns
        if lowercased.contains("memo") || lowercased.contains("memorandum") {
            return .memo
        }
        
        // Letter patterns
        if lowercased.contains("letter") || lowercased.contains("correspondence") {
            return .letter
        }
        
        return .unknown
    }
    
    private func calculateKeywordScore(text: String, keywords: [String]) -> Double {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let wordCount = Double(words.count)
        guard wordCount > 0 else { return 0 }
        
        var matchCount = 0
        for keyword in keywords {
            if text.contains(keyword) {
                matchCount += 1
            }
        }
        
        return Double(matchCount) / Double(keywords.count)
    }
    
    // MARK: - Content Analysis
    
    func extractKeyEntities(from text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag {
                let entity = ExtractedEntity(
                    text: String(text[range]),
                    type: entityType(from: tag),
                    range: range
                )
                entities.append(entity)
            }
            return true
        }
        
        return entities
    }
    
    private func entityType(from tag: NLTag) -> EntityType {
        switch tag {
        case .personalName:
            return .person
        case .organizationName:
            return .organization
        case .placeName:
            return .location
        default:
            return .other
        }
    }
    
    // MARK: - Legal Term Detection
    
    func detectLegalTerms(in text: String) -> [LegalTerm] {
        var terms: [LegalTerm] = []
        let lowercased = text.lowercased()
        
        for term in LegalTerm.commonTerms {
            if lowercased.contains(term.term.lowercased()) {
                terms.append(term)
            }
        }
        
        return terms
    }
    
    // MARK: - Risk Indicators
    
    func detectRiskIndicators(in text: String) -> [RiskIndicator] {
        var indicators: [RiskIndicator] = []
        let lowercased = text.lowercased()
        
        // High risk phrases
        let highRiskPhrases = [
            ("unlimited liability", "No cap on potential damages"),
            ("indemnify and hold harmless", "Broad indemnification obligation"),
            ("sole discretion", "Unilateral decision-making power"),
            ("waive any right", "Waiver of legal rights"),
            ("non-refundable", "No refund provision"),
            ("automatic renewal", "Contract auto-renews without notice"),
            ("binding arbitration", "Waiver of right to sue in court")
        ]
        
        for (phrase, description) in highRiskPhrases {
            if lowercased.contains(phrase) {
                indicators.append(RiskIndicator(
                    phrase: phrase,
                    description: description,
                    severity: .high
                ))
            }
        }
        
        // Medium risk phrases
        let mediumRiskPhrases = [
            ("reasonable efforts", "Vague performance standard"),
            ("material breach", "Undefined materiality threshold"),
            ("force majeure", "Excuse for non-performance"),
            ("consequential damages", "Potential for large damages"),
            ("change of control", "Triggered by ownership changes")
        ]
        
        for (phrase, description) in mediumRiskPhrases {
            if lowercased.contains(phrase) {
                indicators.append(RiskIndicator(
                    phrase: phrase,
                    description: description,
                    severity: .medium
                ))
            }
        }
        
        return indicators
    }
    
    // MARK: - Summary Generation
    
    func generateQuickSummary(of text: String, maxSentences: Int = 3) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 }
        
        let summary = sentences.prefix(maxSentences).joined(separator: ". ")
        return summary.isEmpty ? text.prefix(500).description : summary + "."
    }
}

// MARK: - Supporting Types

struct ExtractedEntity {
    let text: String
    let type: EntityType
    let range: Range<String.Index>
}

enum EntityType {
    case person
    case organization
    case location
    case date
    case money
    case other
}

struct LegalTerm {
    let term: String
    let definition: String
    let category: String
    
    static let commonTerms: [LegalTerm] = [
        LegalTerm(term: "Force Majeure", definition: "Unforeseeable circumstances preventing contract fulfillment", category: "Contract"),
        LegalTerm(term: "Indemnification", definition: "Agreement to compensate for loss or damage", category: "Liability"),
        LegalTerm(term: "Jurisdiction", definition: "Authority of a court to hear a case", category: "Procedure"),
        LegalTerm(term: "Arbitration", definition: "Alternative dispute resolution outside court", category: "Dispute"),
        LegalTerm(term: "Confidentiality", definition: "Obligation to keep information private", category: "Privacy"),
        LegalTerm(term: "Warranty", definition: "Guarantee about product or service quality", category: "Contract"),
        LegalTerm(term: "Liability", definition: "Legal responsibility for actions or debts", category: "Liability"),
        LegalTerm(term: "Breach", definition: "Violation of contract terms", category: "Contract"),
        LegalTerm(term: "Termination", definition: "Ending of contract or agreement", category: "Contract"),
        LegalTerm(term: "Assignment", definition: "Transfer of rights or obligations", category: "Contract")
    ]
}

struct RiskIndicator {
    let phrase: String
    let description: String
    let severity: RiskSeverity
}

enum RiskSeverity: String {
    case high
    case medium
    case low
    
    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
}
