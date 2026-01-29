import Foundation

struct Tool: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: ToolCategory
    let icon: String
    let requiredTier: SubscriptionTier
    let inputSchema: ToolInputSchema?
    let estimatedDuration: TimeInterval?
    let tags: [String]
    
    var isAvailableForFree: Bool {
        requiredTier == .free
    }
}

struct ToolInputSchema: Codable, Equatable, Hashable {
    let fields: [ToolInputField]
}

struct ToolInputField: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let label: String
    let type: FieldType
    let placeholder: String?
    let isRequired: Bool
    let defaultValue: String?
    let options: [String]?
    let maxLength: Int?
    
    enum FieldType: String, Codable, Hashable {
        case text
        case textarea
        case file
        case select
        case multiselect
        case toggle
        case number
    }
}

enum ToolCategory: String, Codable, CaseIterable, Hashable {
    case documentDrafting = "document_drafting"
    case litigationSupport = "litigation_support"
    case contractReview = "contract_review"
    case legalResearch = "legal_research"
    case compliance = "compliance"
    case corporateLaw = "corporate_law"
    case intellectualProperty = "intellectual_property"
    case realEstate = "real_estate"
    case employment = "employment"
    case immigration = "immigration"
    case taxLaw = "tax_law"
    case bankruptcy = "bankruptcy"
    case familyLaw = "family_law"
    case criminalLaw = "criminal_law"
    case environmentalLaw = "environmental_law"
    case healthcareLaw = "healthcare_law"
    case practiceManagement = "practice_management"
    case clientCommunication = "client_communication"
    
    var displayName: String {
        switch self {
        case .documentDrafting: return "Document Drafting"
        case .litigationSupport: return "Litigation Support"
        case .contractReview: return "Contract Review"
        case .legalResearch: return "Legal Research"
        case .compliance: return "Compliance"
        case .corporateLaw: return "Corporate Law"
        case .intellectualProperty: return "Intellectual Property"
        case .realEstate: return "Real Estate"
        case .employment: return "Employment"
        case .immigration: return "Immigration"
        case .taxLaw: return "Tax Law"
        case .bankruptcy: return "Bankruptcy"
        case .familyLaw: return "Family Law"
        case .criminalLaw: return "Criminal Law"
        case .environmentalLaw: return "Environmental Law"
        case .healthcareLaw: return "Healthcare Law"
        case .practiceManagement: return "Practice Management"
        case .clientCommunication: return "Client Communication"
        }
    }
    
    var icon: String {
        switch self {
        case .documentDrafting: return "doc.text"
        case .litigationSupport: return "hammer"
        case .contractReview: return "doc.on.clipboard"
        case .legalResearch: return "magnifyingglass"
        case .compliance: return "checkmark.shield"
        case .corporateLaw: return "building.2"
        case .intellectualProperty: return "lightbulb"
        case .realEstate: return "house"
        case .employment: return "person.2"
        case .immigration: return "globe"
        case .taxLaw: return "dollarsign.circle"
        case .bankruptcy: return "chart.line.downtrend.xyaxis"
        case .familyLaw: return "figure.2.and.child.holdinghands"
        case .criminalLaw: return "exclamationmark.shield"
        case .environmentalLaw: return "leaf"
        case .healthcareLaw: return "cross.case"
        case .practiceManagement: return "briefcase"
        case .clientCommunication: return "bubble.left.and.bubble.right"
        }
    }
    
    var toolCount: Int {
        // Based on main.md tool catalog
        switch self {
        case .documentDrafting: return 45
        case .litigationSupport: return 38
        case .contractReview: return 32
        case .legalResearch: return 28
        case .compliance: return 22
        case .corporateLaw: return 18
        case .intellectualProperty: return 15
        case .realEstate: return 12
        case .employment: return 14
        case .immigration: return 10
        case .taxLaw: return 12
        case .bankruptcy: return 8
        case .familyLaw: return 10
        case .criminalLaw: return 8
        case .environmentalLaw: return 6
        case .healthcareLaw: return 8
        case .practiceManagement: return 10
        case .clientCommunication: return 5
        }
    }
}

// MARK: - Preview Data

extension Tool {
    static let preview = Tool(
        id: "contract_risk_analyzer",
        name: "Contract Risk Analyzer",
        description: "Analyze contracts for potential risks and liabilities",
        category: .contractReview,
        icon: "doc.on.clipboard",
        requiredTier: .pro,
        inputSchema: ToolInputSchema(fields: [
            ToolInputField(
                id: "contract_text",
                name: "contract_text",
                label: "Contract Text",
                type: .textarea,
                placeholder: "Paste your contract here...",
                isRequired: true,
                defaultValue: nil,
                options: nil,
                maxLength: 50000
            )
        ]),
        estimatedDuration: 30,
        tags: ["contract", "risk", "analysis"]
    )
    
    static let previewList: [Tool] = [
        preview,
        Tool(
            id: "document_summarizer",
            name: "Document Summarizer",
            description: "Generate concise summaries of legal documents",
            category: .documentDrafting,
            icon: "doc.text",
            requiredTier: .free,
            inputSchema: nil,
            estimatedDuration: 15,
            tags: ["summary", "document"]
        ),
        Tool(
            id: "case_law_finder",
            name: "Case Law Finder",
            description: "Find relevant case law and precedents",
            category: .legalResearch,
            icon: "magnifyingglass",
            requiredTier: .pro,
            inputSchema: nil,
            estimatedDuration: 45,
            tags: ["research", "case law"]
        )
    ]
}
