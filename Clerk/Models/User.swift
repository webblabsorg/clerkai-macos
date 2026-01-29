import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String?
    let avatarURL: URL?
    let subscriptionTier: SubscriptionTier
    let createdAt: Date
    let lastLoginAt: Date?
    
    // Usage limits
    let monthlyRunsLimit: Int?
    let dailyRunsLimit: Int?
    let monthlyRunsUsed: Int
    let dailyRunsUsed: Int
    
    // Preferences
    var preferredLanguage: String
    var preferredCurrency: String
    
    var isFreeTier: Bool {
        subscriptionTier == .free
    }
    
    var hasUnlimitedRuns: Bool {
        subscriptionTier != .free
    }
    
    var remainingDailyRuns: Int? {
        guard let limit = dailyRunsLimit else { return nil }
        return max(0, limit - dailyRunsUsed)
    }
    
    var remainingMonthlyRuns: Int? {
        guard let limit = monthlyRunsLimit else { return nil }
        return max(0, limit - monthlyRunsUsed)
    }
}

extension User {
    static let preview = User(
        id: "user_preview",
        email: "lawyer@example.com",
        name: "Jane Doe",
        avatarURL: nil,
        subscriptionTier: .pro,
        createdAt: Date(),
        lastLoginAt: Date(),
        monthlyRunsLimit: nil,
        dailyRunsLimit: nil,
        monthlyRunsUsed: 0,
        dailyRunsUsed: 0,
        preferredLanguage: "en",
        preferredCurrency: "USD"
    )
}

// MARK: - Codable Extension for SubscriptionTier

extension SubscriptionTier: Codable {}
