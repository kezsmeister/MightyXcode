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
                        // Create test data if needed (for development)
                        #if DEBUG
                        createTestDataIfNeeded()
                        #endif
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

    #if DEBUG
    private func createTestDataIfNeeded() {
        // Only create test data if no users exist
        guard users.isEmpty else { return }

        let calendar = Calendar.current
        let today = Date()
        let ownerId = AuthState.shared.instantDBUserId

        // Create first user - Aseka
        let aseka = User(name: "Aseka", emoji: "👧", ownerId: ownerId)
        aseka.hasCompletedOnboarding = true

        let asekaSectionId = UUID()
        let asekaSections = CustomSection(
            id: asekaSectionId,
            name: "Kid's Activities",
            icon: "figure.run",
            suggestedActivities: ["Art class", "Ballet", "Chess club", "Coding class", "Dance class",
                                  "Gymnastics", "Karate", "Piano lessons", "Soccer practice", "Swimming"],
            user: aseka
        )
        aseka.customSections.append(asekaSections)
        aseka.tabOrder.append(asekaSectionId.uuidString)

        // Create second user - Arystan
        let arystan = User(name: "Arystan", emoji: "👦", ownerId: ownerId)
        arystan.hasCompletedOnboarding = true

        let arystanSectionId = UUID()
        let arystanSections = CustomSection(
            id: arystanSectionId,
            name: "Kids Activities",
            icon: "figure.run",
            suggestedActivities: ["Art class", "Ballet", "Chess club", "Coding class", "Dance class",
                                  "Gymnastics", "Karate", "Piano lessons", "Soccer practice", "Swimming"],
            user: arystan
        )
        arystan.customSections.append(arystanSections)
        arystan.tabOrder.append(arystanSectionId.uuidString)

        // Insert users
        modelContext.insert(aseka)
        modelContext.insert(arystan)

        // Create test entries for Aseka
        let asekaDates = [
            (days: 3, title: "Art class", hour: 11, minute: 0),
            (days: 4, title: "Ballet", hour: 14, minute: 0),
            (days: 10, title: "Art class", hour: 11, minute: 0),
            (days: 11, title: "Ballet", hour: 14, minute: 0)
        ]

        for dateInfo in asekaDates {
            if let date = calendar.date(byAdding: .day, value: dateInfo.days, to: today) {
                var startTime = calendar.date(bySettingHour: dateInfo.hour, minute: dateInfo.minute, second: 0, of: date)
                var endTime = calendar.date(byAdding: .hour, value: 1, to: startTime ?? date)

                let entry = CustomEntry(
                    title: dateInfo.title,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    section: asekaSections,
                    user: aseka
                )
                modelContext.insert(entry)
            }
        }

        // Create test entries for Arystan
        let arystanDates = [
            (days: 3, title: "Soccer", hour: 11, minute: 0),
            (days: 4, title: "Karate", hour: 16, minute: 0),
            (days: 10, title: "Soccer", hour: 11, minute: 0),
            (days: 11, title: "Karate", hour: 16, minute: 0)
        ]

        for dateInfo in arystanDates {
            if let date = calendar.date(byAdding: .day, value: dateInfo.days, to: today) {
                var startTime = calendar.date(bySettingHour: dateInfo.hour, minute: dateInfo.minute, second: 0, of: date)
                var endTime = calendar.date(byAdding: .hour, value: 1, to: startTime ?? date)

                let entry = CustomEntry(
                    title: dateInfo.title,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    section: arystanSections,
                    user: arystan
                )
                modelContext.insert(entry)
            }
        }

        syncLogger.notice("Created test data for Aseka and Arystan")
    }
    #endif
}
