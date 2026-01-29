import Foundation
import SwiftData

/// SwiftData schema for persistent storage
/// 
/// Migration Strategy:
/// - Use VersionedSchema for schema evolution
/// - Lightweight migrations for additive changes
/// - Custom migration plans for destructive changes

// MARK: - Tool Definition

@Model
final class PersistedTool {
    @Attribute(.unique) var id: String
    var name: String
    var toolDescription: String
    var category: String
    var icon: String
    var requiredTier: String
    var estimatedDurationSeconds: Int
    var tags: [String]
    var inputSchemaJSON: Data?
    var isFavorite: Bool
    var lastUsedAt: Date?
    var useCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        name: String,
        toolDescription: String,
        category: String,
        icon: String,
        requiredTier: String,
        estimatedDurationSeconds: Int,
        tags: [String],
        inputSchemaJSON: Data? = nil,
        isFavorite: Bool = false,
        lastUsedAt: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.toolDescription = toolDescription
        self.category = category
        self.icon = icon
        self.requiredTier = requiredTier
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.tags = tags
        self.inputSchemaJSON = inputSchemaJSON
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Tool Execution History

@Model
final class PersistedExecution {
    @Attribute(.unique) var id: String
    var toolId: String
    var toolName: String
    var userId: String
    var status: String
    var inputJSON: Data?
    var outputJSON: Data?
    var startedAt: Date
    var completedAt: Date?
    var durationMs: Int?
    var tokensUsed: Int?
    var errorCode: String?
    var errorMessage: String?
    var isFavorite: Bool
    
    init(
        id: String,
        toolId: String,
        toolName: String,
        userId: String,
        status: String,
        inputJSON: Data? = nil,
        outputJSON: Data? = nil,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        durationMs: Int? = nil,
        tokensUsed: Int? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.toolId = toolId
        self.toolName = toolName
        self.userId = userId
        self.status = status
        self.inputJSON = inputJSON
        self.outputJSON = outputJSON
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationMs = durationMs
        self.tokensUsed = tokensUsed
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.isFavorite = isFavorite
    }
}

// MARK: - Offline Queue

@Model
final class OfflineQueueItem {
    @Attribute(.unique) var id: String
    var type: String
    var payloadJSON: Data
    var priority: Int
    var createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var errorMessage: String?
    
    init(
        id: String = UUID().uuidString,
        type: String,
        payloadJSON: Data,
        priority: Int = 0,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.type = type
        self.payloadJSON = payloadJSON
        self.priority = priority
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.errorMessage = errorMessage
    }
}

// MARK: - User Preferences

@Model
final class PersistedPreferences {
    @Attribute(.unique) var userId: String
    var theme: String
    var language: String
    var launchAtLogin: Bool
    var showInMenuBar: Bool
    var playSounds: Bool
    var showSuggestionsAutomatically: Bool
    var defaultPanelPosition: String?
    var hotKeyBindingsJSON: Data?
    var updatedAt: Date
    
    init(
        userId: String,
        theme: String = "system",
        language: String = "en",
        launchAtLogin: Bool = true,
        showInMenuBar: Bool = true,
        playSounds: Bool = true,
        showSuggestionsAutomatically: Bool = true,
        defaultPanelPosition: String? = nil,
        hotKeyBindingsJSON: Data? = nil
    ) {
        self.userId = userId
        self.theme = theme
        self.language = language
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.playSounds = playSounds
        self.showSuggestionsAutomatically = showSuggestionsAutomatically
        self.defaultPanelPosition = defaultPanelPosition
        self.hotKeyBindingsJSON = hotKeyBindingsJSON
        self.updatedAt = Date()
    }
}

// MARK: - Cache Entry

@Model
final class CacheEntry {
    @Attribute(.unique) var key: String
    var dataJSON: Data
    var expiresAt: Date
    var createdAt: Date
    
    init(key: String, dataJSON: Data, ttlSeconds: Int = 3600) {
        self.key = key
        self.dataJSON = dataJSON
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(ttlSeconds))
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
}

// MARK: - Schema Configuration

enum ClerkSchema {
    static var models: [any PersistentModel.Type] {
        [
            PersistedTool.self,
            PersistedExecution.self,
            OfflineQueueItem.self,
            PersistedPreferences.self,
            CacheEntry.self
        ]
    }
    
    static func createContainer() throws -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
