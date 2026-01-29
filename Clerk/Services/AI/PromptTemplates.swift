import Foundation

/// Templates for AI prompts used by legal tools
struct PromptTemplates {
    
    // MARK: - Contract Analysis
    
    static let contractRiskAnalyzer = """
    You are a legal contract analyst. Analyze the following contract for risks and issues.
    
    CONTRACT TEXT:
    {contract_text}
    
    JURISDICTION: {jurisdiction}
    
    Provide a comprehensive risk analysis including:
    
    ## Overall Risk Score
    Rate the contract risk from 1-10 (1 = very low risk, 10 = extremely high risk)
    
    ## High Risk Items
    List critical issues that require immediate attention:
    - Unlimited liability clauses
    - Broad indemnification obligations
    - One-sided termination rights
    - Waiver of important legal rights
    - Missing essential protections
    
    ## Medium Risk Items
    List concerning provisions that should be negotiated:
    - Vague or ambiguous terms
    - Unfavorable payment terms
    - Restrictive covenants
    - Automatic renewal clauses
    
    ## Low Risk Items
    List minor issues for awareness:
    - Standard boilerplate that could be improved
    - Minor formatting or drafting issues
    
    ## Missing Clauses
    Identify important clauses that are absent:
    - Force majeure
    - Dispute resolution
    - Confidentiality
    - Data protection
    
    ## Recommendations
    Provide specific recommendations for negotiation or revision.
    
    Format your response in clear markdown with headers and bullet points.
    Reference specific sections (e.g., §8.1, Section 12) when applicable.
    """
    
    static let contractSummarizer = """
    You are a legal document summarizer. Provide a comprehensive summary of this contract.
    
    CONTRACT TEXT:
    {contract_text}
    
    Provide a structured summary including:
    
    ## Document Overview
    - Type of agreement
    - Effective date
    - Term/duration
    
    ## Parties
    - Party A (name, role, obligations)
    - Party B (name, role, obligations)
    
    ## Key Terms
    - Primary obligations
    - Payment terms
    - Deliverables or services
    
    ## Important Dates
    - Effective date
    - Termination date
    - Key milestones or deadlines
    
    ## Notable Provisions
    - Unusual or non-standard terms
    - Particularly favorable or unfavorable clauses
    
    ## Summary
    A brief 2-3 sentence executive summary.
    """
    
    static let clauseExtractor = """
    You are a legal clause extraction specialist. Extract and categorize clauses from this contract.
    
    CONTRACT TEXT:
    {contract_text}
    
    CLAUSE TYPES TO EXTRACT: {clause_types}
    
    For each clause type requested, provide:
    
    ## [Clause Type]
    
    ### Location
    Section/paragraph reference
    
    ### Full Text
    The complete clause text
    
    ### Analysis
    - Purpose of the clause
    - Key obligations
    - Potential issues or concerns
    - Comparison to standard market terms
    
    ### Risk Level
    Low / Medium / High with brief explanation
    
    If a requested clause type is not found, note its absence and explain the implications.
    """
    
    // MARK: - Legal Research
    
    static let caseLawFinder = """
    You are a legal research assistant. Find relevant case law for the following legal issue.
    
    LEGAL ISSUE:
    {legal_issue}
    
    JURISDICTION: {jurisdiction}
    DATE RANGE: {date_range}
    
    Provide relevant case citations and analysis:
    
    ## Most Relevant Cases
    
    For each case, provide:
    
    ### [Case Name] ([Year])
    **Citation:** [Full citation]
    **Court:** [Court name and level]
    **Jurisdiction:** [State/Federal]
    
    **Facts:** Brief summary of relevant facts
    
    **Holding:** The court's decision and reasoning
    
    **Relevance:** How this case applies to the legal issue at hand
    
    **Status:** Whether the case is still good law (not overruled or distinguished)
    
    ## Analysis
    Synthesize how these cases together inform the legal issue.
    
    ## Recommendations
    Suggest additional research directions or related legal theories to explore.
    
    Note: Provide accurate citations. If you're uncertain about a citation, indicate this clearly.
    """
    
    static let citationValidator = """
    You are a legal citation validator. Check the following citations for accuracy and current status.
    
    CITATIONS:
    {citations}
    
    For each citation, verify:
    
    ## [Citation]
    
    ### Format Check
    - Is the citation format correct? (Bluebook, state-specific, etc.)
    - Suggested corrections if needed
    
    ### Case Status
    - Is this case still good law?
    - Has it been overruled, distinguished, or limited?
    - Any negative treatment to be aware of?
    
    ### Related Cases
    - Key cases that cite this decision
    - Cases that may have modified the holding
    
    ### Recommendation
    - Safe to cite / Cite with caution / Do not cite
    - Suggested alternative citations if problematic
    """
    
    // MARK: - Document Drafting
    
    static let documentSummarizer = """
    You are a legal document summarizer. Create a clear, comprehensive summary.
    
    DOCUMENT TEXT:
    {document_text}
    
    SUMMARY LENGTH: {summary_length}
    
    Provide a summary that includes:
    
    ## Document Type
    Identify what type of legal document this is.
    
    ## Purpose
    The main purpose or objective of the document.
    
    ## Key Points
    The most important information, organized by topic.
    
    ## Parties & Roles
    Who is involved and their respective roles/obligations.
    
    ## Important Terms
    Key definitions, dates, amounts, or conditions.
    
    ## Action Items
    Any required actions or next steps.
    
    ## Executive Summary
    A brief 2-3 sentence overview suitable for quick review.
    """
    
    static let legalEmailDrafter = """
    You are a legal email drafting assistant. Draft a professional legal email.
    
    CONTEXT:
    {context}
    
    TONE: {tone}
    RECIPIENT: {recipient_type}
    
    Draft an email that:
    
    1. Uses appropriate salutation for the recipient type
    2. Maintains the requested tone throughout
    3. Clearly states the purpose in the first paragraph
    4. Provides necessary details and context
    5. Includes any required disclaimers or caveats
    6. Uses professional closing
    
    Format:
    
    Subject: [Suggested subject line]
    
    [Salutation]
    
    [Body paragraphs]
    
    [Closing]
    [Signature block placeholder]
    
    ---
    
    Notes:
    - Key points covered
    - Suggested attachments if applicable
    - Follow-up actions recommended
    """
    
    // MARK: - Compliance
    
    static let gdprComplianceChecker = """
    You are a GDPR compliance specialist. Analyze this document for GDPR compliance.
    
    DOCUMENT TEXT:
    {document_text}
    
    DOCUMENT TYPE: {document_type}
    
    Evaluate compliance with key GDPR requirements:
    
    ## Compliance Score
    Rate overall GDPR compliance from 1-10.
    
    ## Article-by-Article Analysis
    
    ### Lawful Basis (Art. 6)
    - Is a lawful basis for processing clearly stated?
    - Is it appropriate for the processing activities?
    
    ### Consent (Art. 7)
    - If consent is the basis, is it freely given, specific, informed, and unambiguous?
    - Is withdrawal of consent clearly explained?
    
    ### Transparency (Art. 13-14)
    - Is the identity of the controller provided?
    - Are purposes of processing clearly stated?
    - Are data subject rights explained?
    
    ### Data Subject Rights (Art. 15-22)
    - Right of access
    - Right to rectification
    - Right to erasure
    - Right to data portability
    - Right to object
    
    ### Data Security (Art. 32)
    - Are appropriate security measures mentioned?
    
    ### International Transfers (Art. 44-49)
    - Are international transfers addressed?
    - Is the legal mechanism specified?
    
    ## Non-Compliant Items
    List specific issues requiring remediation.
    
    ## Recommendations
    Specific changes needed for compliance.
    """
    
    // MARK: - Utility Functions
    
    static func fillTemplate(_ template: String, with values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
    
    static func getTemplate(for toolId: String) -> String? {
        switch toolId {
        case "contract_risk_analyzer":
            return contractRiskAnalyzer
        case "contract_summarizer":
            return contractSummarizer
        case "clause_extractor":
            return clauseExtractor
        case "case_law_finder":
            return caseLawFinder
        case "citation_validator":
            return citationValidator
        case "document_summarizer":
            return documentSummarizer
        case "legal_email_drafter":
            return legalEmailDrafter
        case "gdpr_compliance_checker":
            return gdprComplianceChecker
        default:
            return nil
        }
    }
}
