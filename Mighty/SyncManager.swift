import Foundation
import SwiftData
import os.log

private let syncLogger = Logger(subsystem: "com.mighty.app", category: "SyncManager")

/// Coordinates all cloud sync operations and provides observable sync status
@Observable
final class SyncManager {
    static let shared = SyncManager()

    // MARK: - Observable State

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var lastSyncError: String?
    private(set) var syncStatus: SyncStatus = .idle

    enum SyncStatus: Equatable {
        case idle
        case syncing(String)  // message describing what's syncing
        case success
        case error(String)
    }

    // MARK: - Private State

    private var syncTask: Task<Void, Never>?
    private var pendingSyncRequest = false
    private let debounceInterval: Duration = .milliseconds(500)

    private init() {}

    // MARK: - Public API

    /// Trigger a full sync (profiles + entries) with debouncing
    /// Call this after any data change
    func triggerSync(context: ModelContext) {
        // Skip if not authenticated
        guard AuthState.shared.isAuthenticated else {
            syncLogger.info("Skipping sync - not authenticated")
            return
        }

        // If already syncing, mark that we need another sync after
        if isSyncing {
            pendingSyncRequest = true
            syncLogger.info("Sync already in progress, will sync again after")
            return
        }

        // Cancel any pending debounced sync
        syncTask?.cancel()

        // Debounce: wait a bit before syncing to batch rapid changes
        syncTask = Task { @MainActor in
            try? await Task.sleep(for: debounceInterval)

            guard !Task.isCancelled else { return }

            await performFullSync(context: context)

            // Check if another sync was requested while we were syncing
            if pendingSyncRequest {
                pendingSyncRequest = false
                syncLogger.info("Processing pending sync request")
                await performFullSync(context: context)
            }
        }
    }

    /// Perform immediate full sync without debouncing
    @MainActor
    func performFullSync(context: ModelContext) async {
        guard AuthState.shared.isAuthenticated else {
            syncLogger.info("Skipping sync - not authenticated")
            return
        }

        guard !isSyncing else {
            pendingSyncRequest = true
            return
        }

        isSyncing = true
        syncStatus = .syncing("Syncing profiles...")
        lastSyncError = nil

        syncLogger.info("Starting full sync...")

        do {
            // Step 1: Sync profiles
            syncStatus = .syncing("Syncing profiles...")
            try await ProfileSyncService.shared.performFullSync(context: context)
            syncLogger.info("Profile sync completed")

            // Step 2: Get users and sync their entries
            let currentOwnerId = AuthState.shared.instantDBUserId
            let descriptor = FetchDescriptor<User>()
            let allUsers = try context.fetch(descriptor)
            let users = currentOwnerId != nil
                ? allUsers.filter { $0.ownerId == currentOwnerId }
                : allUsers.filter { $0.ownerId == nil }

            syncLogger.info("Found \(users.count) users to sync entries for")

            for user in users {
                syncStatus = .syncing("Syncing \(user.name)'s activities...")
                try await EntrySyncService.shared.performFullSync(context: context, user: user)
                syncLogger.info("Entry sync completed for \(user.name)")
            }

            // Success
            lastSyncDate = Date()
            syncStatus = .success
            syncLogger.info("Full sync completed successfully")

            // Reset to idle after a moment
            try? await Task.sleep(for: .seconds(2))
            if case .success = syncStatus {
                syncStatus = .idle
            }

        } catch {
            syncLogger.error("Sync error: \(error.localizedDescription)")
            lastSyncError = error.localizedDescription
            syncStatus = .error(error.localizedDescription)

            // Reset to idle after showing error
            try? await Task.sleep(for: .seconds(5))
            if case .error = syncStatus {
                syncStatus = .idle
            }
        }

        isSyncing = false
    }

    /// Format last sync time for display
    var lastSyncDescription: String? {
        guard let date = lastSyncDate else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
