import Foundation
import SwiftData
import Combine
import Network

/// Service for managing offline queue and sync
/// 
/// Sync Strategy:
/// - Queue operations when offline
/// - Process queue on network restoration
/// - Conflict resolution: server wins for reads, merge for writes
/// - Retry with exponential backoff
final class OfflineQueueService {
    static let shared = OfflineQueueService()
    
    @Published private(set) var isOnline = true
    @Published private(set) var pendingItemCount = 0
    @Published private(set) var isSyncing = false
    
    private var modelContext: ModelContext?
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.clerk.networkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    private let maxRetries = 3
    private let baseBackoffSeconds: Double = 2.0
    
    private init() {
        setupNetworkMonitoring()
    }
    
    func configure(with container: ModelContainer) {
        self.modelContext = ModelContext(container)
        updatePendingCount()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                if wasOffline && path.status == .satisfied {
                    self?.processQueue()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Queue Operations
    
    func enqueue<T: Encodable>(type: QueueItemType, payload: T, priority: Int = 0) {
        guard let context = modelContext else { return }
        
        do {
            let payloadData = try JSONEncoder().encode(payload)
            let item = OfflineQueueItem(
                type: type.rawValue,
                payloadJSON: payloadData,
                priority: priority
            )
            context.insert(item)
            try context.save()
            updatePendingCount()
        } catch {
            logError(error, category: .storage)
        }
    }
    
    func processQueue() {
        guard isOnline, !isSyncing else { return }
        
        Task {
            await processQueueAsync()
        }
    }
    
    private func processQueueAsync() async {
        guard let context = modelContext else { return }
        
        await MainActor.run { isSyncing = true }
        defer { Task { @MainActor in isSyncing = false } }
        
        do {
            let descriptor = FetchDescriptor<OfflineQueueItem>(
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.createdAt)
                ]
            )
            
            let items = try context.fetch(descriptor)
            
            for item in items {
                if !isOnline { break }
                
                let success = await processItem(item)
                
                if success {
                    context.delete(item)
                } else {
                    item.retryCount += 1
                    item.lastAttemptAt = Date()
                    
                    if item.retryCount >= maxRetries {
                        item.errorMessage = "Max retries exceeded"
                        // Keep failed items for manual review
                    }
                }
                
                try context.save()
            }
            
            await MainActor.run { updatePendingCount() }
        } catch {
            logError(error, category: .storage)
        }
    }
    
    private func processItem(_ item: OfflineQueueItem) async -> Bool {
        guard let type = QueueItemType(rawValue: item.type) else {
            return false
        }
        
        // Exponential backoff
        if item.retryCount > 0 {
            let delay = baseBackoffSeconds * pow(2.0, Double(item.retryCount - 1))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        do {
            switch type {
            case .toolExecution:
                return try await syncToolExecution(item.payloadJSON)
            case .favoriteToggle:
                return try await syncFavoriteToggle(item.payloadJSON)
            case .preferencesUpdate:
                return try await syncPreferencesUpdate(item.payloadJSON)
            case .usageLog:
                return try await syncUsageLog(item.payloadJSON)
            }
        } catch {
            item.errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Sync Operations
    
    private func syncToolExecution(_ data: Data) async throws -> Bool {
        let execution = try JSONDecoder().decode(ToolExecutionSyncPayload.self, from: data)
        
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: "executions",
            method: .post,
            body: execution
        )
        
        return true
    }
    
    private func syncFavoriteToggle(_ data: Data) async throws -> Bool {
        let payload = try JSONDecoder().decode(FavoriteTogglePayload.self, from: data)
        
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: "tools/\(payload.toolId)/favorite",
            method: payload.isFavorite ? .post : .delete
        )
        
        return true
    }
    
    private func syncPreferencesUpdate(_ data: Data) async throws -> Bool {
        let payload = try JSONDecoder().decode(PreferencesUpdatePayload.self, from: data)
        
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: "users/preferences",
            method: .put,
            body: payload
        )
        
        return true
    }
    
    private func syncUsageLog(_ data: Data) async throws -> Bool {
        let payload = try JSONDecoder().decode(UsageLogPayload.self, from: data)
        
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: "usage/log",
            method: .post,
            body: payload
        )
        
        return true
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict<T: Codable>(local: T, remote: T, strategy: ConflictStrategy) -> T {
        switch strategy {
        case .serverWins:
            return remote
        case .clientWins:
            return local
        case .merge:
            // For merge, caller should implement specific logic
            return remote
        case .lastWriteWins:
            // Would need timestamps; default to server
            return remote
        }
    }
    
    // MARK: - Cache Invalidation
    
    func invalidateCache(for keys: [String]? = nil) {
        guard let context = modelContext else { return }
        
        do {
            if let keys = keys {
                for key in keys {
                    let descriptor = FetchDescriptor<CacheEntry>(
                        predicate: #Predicate { $0.key == key }
                    )
                    let entries = try context.fetch(descriptor)
                    entries.forEach { context.delete($0) }
                }
            } else {
                // Invalidate all expired entries
                let now = Date()
                let descriptor = FetchDescriptor<CacheEntry>(
                    predicate: #Predicate { $0.expiresAt < now }
                )
                let entries = try context.fetch(descriptor)
                entries.forEach { context.delete($0) }
            }
            
            try context.save()
        } catch {
            logError(error, category: .storage)
        }
    }
    
    func getCached<T: Codable>(_ key: String) -> T? {
        guard let context = modelContext else { return nil }
        
        do {
            let descriptor = FetchDescriptor<CacheEntry>(
                predicate: #Predicate { $0.key == key }
            )
            
            guard let entry = try context.fetch(descriptor).first,
                  !entry.isExpired else {
                return nil
            }
            
            return try JSONDecoder().decode(T.self, from: entry.dataJSON)
        } catch {
            return nil
        }
    }
    
    func setCache<T: Codable>(_ key: String, value: T, ttlSeconds: Int = 3600) {
        guard let context = modelContext else { return }
        
        do {
            let data = try JSONEncoder().encode(value)
            
            // Remove existing entry
            let descriptor = FetchDescriptor<CacheEntry>(
                predicate: #Predicate { $0.key == key }
            )
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            
            // Insert new entry
            let entry = CacheEntry(key: key, dataJSON: data, ttlSeconds: ttlSeconds)
            context.insert(entry)
            
            try context.save()
        } catch {
            logError(error, category: .storage)
        }
    }
    
    // MARK: - Helpers
    
    private func updatePendingCount() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<OfflineQueueItem>()
            pendingItemCount = try context.fetchCount(descriptor)
        } catch {
            pendingItemCount = 0
        }
    }
    
    func clearQueue() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<OfflineQueueItem>()
            let items = try context.fetch(descriptor)
            items.forEach { context.delete($0) }
            try context.save()
            updatePendingCount()
        } catch {
            logError(error, category: .storage)
        }
    }
}

// MARK: - Types

enum QueueItemType: String, Codable {
    case toolExecution
    case favoriteToggle
    case preferencesUpdate
    case usageLog
}

enum ConflictStrategy {
    case serverWins
    case clientWins
    case merge
    case lastWriteWins
}

struct ToolExecutionSyncPayload: Codable {
    let executionId: String
    let toolId: String
    let input: [String: String]
    let output: String?
    let status: String
    let durationMs: Int?
    let tokensUsed: Int?
    let timestamp: Date
}

struct FavoriteTogglePayload: Codable {
    let toolId: String
    let isFavorite: Bool
    let timestamp: Date
}

struct PreferencesUpdatePayload: Codable {
    let preferences: [String: String]
    let timestamp: Date
}

struct UsageLogPayload: Codable {
    let events: [UsageEvent]
    
    struct UsageEvent: Codable {
        let type: String
        let toolId: String?
        let timestamp: Date
        let metadata: [String: String]?
    }
}
