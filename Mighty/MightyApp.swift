import SwiftUI
import SwiftData
import UserNotifications
import os.log

private let syncLogger = Logger(subsystem: "com.mighty.app", category: "Sync")

@main
struct MightyApp: App {
    init() {
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MediaEntry.self,
            User.self,
            CustomSection.self,
            CustomEntry.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Using InstantDB for cloud sync instead
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var allUsers: [User]
    @Query private var customEntries: [CustomEntry]
    @State private var hasCompletedOnboarding = false

    // Filter users by current authenticated account
    private var users: [User] {
        let currentOwnerId = AuthState.shared.instantDBUserId
        if let ownerId = currentOwnerId {
            return allUsers.filter { $0.ownerId == ownerId }
        } else {
            return allUsers.filter { $0.ownerId == nil }
        }
    }

    private var needsOnboarding: Bool {
        // Show onboarding if no users exist or if existing user hasn't completed it
        if users.isEmpty {
            return true
        }
        // Check if any user has completed onboarding
        return !users.contains { $0.hasCompletedOnboarding }
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding || !needsOnboarding {
                ContentView()
                    .onAppear {
                        // Migrate existing users who have data
                        migrateExistingUsers()
                        // Regenerate recurring entries
                        regenerateRecurringEntries()
                    }
                    .task {
                        // Auto-sync entries when app launches
                        await performAutoSync()
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }

    private func performAutoSync() async {
        // Wait a moment for SwiftData to load
        try? await Task.sleep(for: .milliseconds(500))

        // Use SyncManager for coordinated sync
        await SyncManager.shared.performFullSync(context: modelContext)

        // Clean up duplicate entries from cloud database
        do {
            let removedCount = try await EntrySyncService.shared.cleanupCloudDuplicates()
            if removedCount > 0 {
                syncLogger.notice("Cleaned up \(removedCount) duplicate entries from cloud")
            }
        } catch {
            syncLogger.error("Failed to cleanup cloud duplicates: \(error.localizedDescription)")
        }

        // Clean up any local duplicates
        cleanupLocalDuplicateEntries()
    }

    private func cleanupLocalDuplicateEntries() {
        let fetchDescriptor = FetchDescriptor<CustomEntry>()
        guard let allEntries = try? modelContext.fetch(fetchDescriptor) else { return }

        let calendar = Calendar.current
        var seenKeys = Set<String>()
        var entriesToDelete: [CustomEntry] = []

        let sortedEntries = allEntries.sorted { $0.updatedAt > $1.updatedAt }

        for entry in sortedEntries {
            let hour = entry.startTime.map { calendar.component(.hour, from: $0) } ?? -1
            let minute = entry.startTime.map { calendar.component(.minute, from: $0) } ?? -1
            let day = calendar.startOfDay(for: entry.date).timeIntervalSince1970
            let userId = entry.user?.id.uuidString ?? "unknown"
            // Include userId in key to prevent deleting entries from different users
            let key = "\(userId)-\(entry.title)-\(day)-\(hour)-\(minute)"

            if seenKeys.contains(key) {
                entriesToDelete.append(entry)
            } else {
                seenKeys.insert(key)
            }
        }

        if !entriesToDelete.isEmpty {
            syncLogger.notice("Removing \(entriesToDelete.count) local duplicate entries")
            for entry in entriesToDelete {
                modelContext.delete(entry)
            }
        }
    }

    private func migrateExistingUsers() {
        for user in users {
            // If user has entries, they're an existing user - auto-enable their templates
            let hasMovies = user.entries.contains { $0.mediaType == .movies }
            let hasBooks = user.entries.contains { $0.mediaType == .books }

            if !user.hasCompletedOnboarding && (!user.entries.isEmpty || !user.customSections.isEmpty) {
                user.hasCompletedOnboarding = true

                if hasMovies && !user.enabledTemplates.contains("movies") {
                    user.enabledTemplates.append("movies")
                    if !user.tabOrder.contains("movies") {
                        user.tabOrder.insert("movies", at: 0)
                    }
                }
                if hasBooks && !user.enabledTemplates.contains("books") {
                    user.enabledTemplates.append("books")
                    if !user.tabOrder.contains("books") {
                        let insertIndex = user.tabOrder.firstIndex(of: "movies").map { $0 + 1 } ?? 0
                        user.tabOrder.insert("books", at: insertIndex)
                    }
                }
            }
        }
    }

    private func regenerateRecurringEntries() {
        // Find all recurring templates
        let templates = customEntries.filter { $0.isRecurrenceTemplate }

        for template in templates {
            guard let groupId = template.recurrenceGroupId else { continue }

            // Get existing entries for this group
            let existingInGroup = customEntries.filter { $0.recurrenceGroupId == groupId }

            // Regenerate future instances
            RecurrenceService.shared.regenerateFutureInstances(
                for: groupId,
                template: template,
                existingEntries: existingInGroup,
                in: modelContext
            )
        }

        // Schedule notifications for upcoming entries
        rescheduleUpcomingNotifications()
    }

    private func rescheduleUpcomingNotifications() {
        let calendar = Calendar.current
        let today = Date()
        guard let twoWeeksOut = calendar.date(byAdding: .weekOfYear, value: 2, to: today) else { return }

        let upcomingEntries = customEntries.filter {
            $0.date >= today && $0.date <= twoWeeksOut && $0.notifyBefore && $0.startTime != nil
        }

        NotificationManager.shared.scheduleNotifications(for: upcomingEntries)
    }
}
