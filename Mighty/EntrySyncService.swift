import Foundation
import SwiftData
import os.log

private let entrySyncLogger = Logger(subsystem: "com.mighty.app", category: "EntrySync")

/// Tracks recently deleted entries to prevent them from being restored during sync
final class DeletionTracker {
    static let shared = DeletionTracker()

    private var deletedCustomEntryIds = Set<UUID>()
    private var deletedMediaEntryIds = Set<UUID>()
    private var deletedSectionIds = Set<UUID>()
    private var deletedProfileIds = Set<UUID>()

    private init() {}

    func markCustomEntryDeleted(_ id: UUID) {
        deletedCustomEntryIds.insert(id)
    }

    func markMediaEntryDeleted(_ id: UUID) {
        deletedMediaEntryIds.insert(id)
    }

    func markSectionDeleted(_ id: UUID) {
        deletedSectionIds.insert(id)
    }

    func markProfileDeleted(_ id: UUID) {
        deletedProfileIds.insert(id)
    }

    func isCustomEntryDeleted(_ id: UUID) -> Bool {
        deletedCustomEntryIds.contains(id)
    }

    func isMediaEntryDeleted(_ id: UUID) -> Bool {
        deletedMediaEntryIds.contains(id)
    }

    func isSectionDeleted(_ id: UUID) -> Bool {
        deletedSectionIds.contains(id)
    }

    func isProfileDeleted(_ id: UUID) -> Bool {
        deletedProfileIds.contains(id)
    }
}

/// Service for syncing entries between local SwiftData and InstantDB cloud
actor EntrySyncService {
    static let shared = EntrySyncService()

    private init() {}

    // MARK: - Sync CustomSections to Cloud

    func syncSectionsToCloud(sections: [CustomSection], userId: UUID) async throws {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        var steps: [[Any]] = []

        for section in sections {
            let sectionId = section.id.uuidString
            let sectionData: [String: Any] = [
                "localId": section.id.uuidString,
                "name": section.name,
                "icon": section.icon,
                "sortOrder": section.sortOrder,
                "suggestedActivities": section.suggestedActivities,
                "notificationsEnabled": section.notificationsEnabled,
                "updatedAt": ISO8601DateFormatter().string(from: section.updatedAt)
            ]

            let updateStep = InstantDBService.shared.updateStep(
                namespace: "customSections",
                id: sectionId,
                data: sectionData
            )
            steps.append(updateStep)

            // Link to parent kid profile
            let linkStep = InstantDBService.shared.linkStep(
                namespace: "customSections",
                id: sectionId,
                linkField: "kidProfile",
                linkedId: userId.uuidString
            )
            steps.append(linkStep)
        }

        if !steps.isEmpty {
            try await InstantDBService.shared.transact(steps)
        }
    }

    // MARK: - Sync MediaEntries to Cloud

    func syncMediaEntriesToCloud(entries: [MediaEntry], userId: UUID) async throws {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        var steps: [[Any]] = []

        for entry in entries {
            let entryId = entry.id.uuidString
            var entryData: [String: Any] = [
                "localId": entry.id.uuidString,
                "title": entry.title,
                "mediaTypeRaw": entry.mediaTypeRaw,
                "date": ISO8601DateFormatter().string(from: entry.date),
                "updatedAt": ISO8601DateFormatter().string(from: entry.updatedAt)
            ]

            if let videoTypeRaw = entry.videoTypeRaw {
                entryData["videoTypeRaw"] = videoTypeRaw
            }
            if let endDate = entry.endDate {
                entryData["endDate"] = ISO8601DateFormatter().string(from: endDate)
            }
            if let imageURL = entry.imageURL {
                entryData["imageURL"] = imageURL
            }
            if let rating = entry.rating {
                entryData["rating"] = rating
            }
            if let notes = entry.notes {
                entryData["notes"] = notes
            }

            let updateStep = InstantDBService.shared.updateStep(
                namespace: "mediaEntries",
                id: entryId,
                data: entryData
            )
            steps.append(updateStep)

            // Link to kid profile
            let linkStep = InstantDBService.shared.linkStep(
                namespace: "mediaEntries",
                id: entryId,
                linkField: "kidProfile",
                linkedId: userId.uuidString
            )
            steps.append(linkStep)
        }

        if !steps.isEmpty {
            try await InstantDBService.shared.transact(steps)
        }
    }

    // MARK: - Sync CustomEntries to Cloud

    func syncCustomEntriesToCloud(entries: [CustomEntry]) async throws {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        var steps: [[Any]] = []

        for entry in entries {
            guard let sectionId = entry.section?.id else { continue }

            let entryId = entry.id.uuidString
            var entryData: [String: Any] = [
                "localId": entry.id.uuidString,
                "title": entry.title,
                "date": ISO8601DateFormatter().string(from: entry.date),
                "notifyBefore": entry.notifyBefore,
                "isRecurrenceTemplate": entry.isRecurrenceTemplate,
                "updatedAt": ISO8601DateFormatter().string(from: entry.updatedAt)
            ]

            // Optional fields
            if let endDate = entry.endDate {
                entryData["endDate"] = ISO8601DateFormatter().string(from: endDate)
            }
            if let startTime = entry.startTime {
                entryData["startTime"] = ISO8601DateFormatter().string(from: startTime)
            }
            if let endTime = entry.endTime {
                entryData["endTime"] = ISO8601DateFormatter().string(from: endTime)
            }
            if let rating = entry.rating {
                entryData["rating"] = rating
            }
            if let notes = entry.notes {
                entryData["notes"] = notes
            }
            // Recurrence fields
            if let recurrenceGroupId = entry.recurrenceGroupId {
                entryData["recurrenceGroupId"] = recurrenceGroupId.uuidString
            }
            if let recurrencePatternRaw = entry.recurrencePatternRaw {
                entryData["recurrencePatternRaw"] = recurrencePatternRaw
            }
            if let recurrenceWeekdays = entry.recurrenceWeekdays {
                entryData["recurrenceWeekdays"] = recurrenceWeekdays
            }
            if let recurrenceEndDate = entry.recurrenceEndDate {
                entryData["recurrenceEndDate"] = ISO8601DateFormatter().string(from: recurrenceEndDate)
            }
            if let recurrenceOccurrenceCount = entry.recurrenceOccurrenceCount {
                entryData["recurrenceOccurrenceCount"] = recurrenceOccurrenceCount
            }

            // Note: imagesData is intentionally NOT synced (too large)

            let updateStep = InstantDBService.shared.updateStep(
                namespace: "customEntries",
                id: entryId,
                data: entryData
            )
            steps.append(updateStep)

            // Link to section
            let linkStep = InstantDBService.shared.linkStep(
                namespace: "customEntries",
                id: entryId,
                linkField: "section",
                linkedId: sectionId.uuidString
            )
            steps.append(linkStep)
        }

        if !steps.isEmpty {
            try await InstantDBService.shared.transact(steps)
        }
    }

    // MARK: - Fetch from Cloud

    func fetchSectionsFromCloud(userId: UUID) async throws -> [CloudCustomSection] {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        entrySyncLogger.notice("Fetching sections for user: \(userId.uuidString)")

        // Query sections with kidProfile relationship
        let query: [String: Any] = [
            "customSections": [
                "kidProfile": [String: Any]()
            ]
        ]

        let response: CustomSectionsWithProfileResponse = try await InstantDBService.shared.query(query)

        // Filter by kidProfile localId matching the user
        let userIdStr = userId.uuidString
        let filteredSections = response.customSections.filter { section in
            section.kidProfile?.localId == userIdStr
        }

        entrySyncLogger.notice("Fetched \(response.customSections.count) total, \(filteredSections.count) for user \(userId.uuidString)")
        return filteredSections.map { $0.toCloudCustomSection() }
    }

    func fetchMediaEntriesFromCloud(userId: UUID) async throws -> [CloudMediaEntry] {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        entrySyncLogger.notice("Fetching media entries for user: \(userId.uuidString)")

        // Query media entries with kidProfile relationship
        let query: [String: Any] = [
            "mediaEntries": [
                "kidProfile": [String: Any]()
            ]
        ]

        let response: MediaEntriesWithProfileResponse = try await InstantDBService.shared.query(query)

        // Filter by kidProfile localId matching the user
        let userIdStr = userId.uuidString
        let filteredEntries = response.mediaEntries.filter { entry in
            entry.kidProfile?.localId == userIdStr
        }

        entrySyncLogger.notice("Fetched \(response.mediaEntries.count) total, \(filteredEntries.count) for user \(userId.uuidString)")
        return filteredEntries.map { $0.toCloudMediaEntry() }
    }

    func fetchCustomEntriesFromCloud(sectionId: UUID) async throws -> [CloudCustomEntry] {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        entrySyncLogger.notice("Fetching custom entries for section: \(sectionId.uuidString)")

        // Query custom entries with section relationship
        let query: [String: Any] = [
            "customEntries": [
                "section": [String: Any]()
            ]
        ]

        let response: CustomEntriesWithSectionResponse = try await InstantDBService.shared.query(query)

        // Filter entries by section localId
        let sectionIdStr = sectionId.uuidString
        let filteredEntries = response.customEntries.filter { entry in
            entry.section?.localId == sectionIdStr
        }

        entrySyncLogger.notice("Fetched \(response.customEntries.count) total, \(filteredEntries.count) for section \(sectionId.uuidString)")
        return filteredEntries.map { $0.toCloudCustomEntry() }
    }

    // MARK: - Merge Cloud → Local

    @MainActor
    func mergeSections(_ cloudSections: [CloudCustomSection], into context: ModelContext, user: User) throws {
        let localSections = user.customSections

        // Track sections we've already processed to prevent duplicates within this sync
        var processedKeys = Set<String>()
        for section in localSections {
            let key = "\(section.name)-\(section.icon)"
            processedKeys.insert(key)
        }

        for cloudSection in cloudSections {
            // Skip sections that were recently deleted locally
            if let sectionUUID = UUID(uuidString: cloudSection.localId),
               DeletionTracker.shared.isSectionDeleted(sectionUUID) {
                entrySyncLogger.info("Skipping deleted section: \(cloudSection.localId)")
                continue
            }

            if let existingSection = localSections.first(where: { $0.id.uuidString == cloudSection.localId }) {
                // Update if cloud is newer
                if let cloudDate = ISO8601DateFormatter().date(from: cloudSection.updatedAt),
                   cloudDate > existingSection.updatedAt {
                    existingSection.name = cloudSection.name
                    existingSection.icon = cloudSection.icon
                    existingSection.sortOrder = cloudSection.sortOrder
                    existingSection.suggestedActivities = cloudSection.suggestedActivities
                    existingSection.notificationsEnabled = cloudSection.notificationsEnabled
                    existingSection.updatedAt = cloudDate
                }
            } else {
                // Build key for this cloud section
                let cloudKey = "\(cloudSection.name)-\(cloudSection.icon)"

                // Check if we've already processed this section
                if processedKeys.contains(cloudKey) {
                    entrySyncLogger.info("Skipping duplicate section: \(cloudSection.name)")
                    continue
                }

                // Mark as processed
                processedKeys.insert(cloudKey)

                // Create new section from cloud
                let newSection = CustomSection(
                    id: UUID(uuidString: cloudSection.localId) ?? UUID(),
                    name: cloudSection.name,
                    icon: cloudSection.icon,
                    sortOrder: cloudSection.sortOrder,
                    suggestedActivities: cloudSection.suggestedActivities,
                    notificationsEnabled: cloudSection.notificationsEnabled,
                    user: user
                )
                if let cloudDate = ISO8601DateFormatter().date(from: cloudSection.updatedAt) {
                    newSection.updatedAt = cloudDate
                }
                context.insert(newSection)
            }
        }

        try context.save()
    }

    @MainActor
    func mergeMediaEntries(_ cloudEntries: [CloudMediaEntry], into context: ModelContext, user: User) throws {
        let localEntries = user.entries

        // Track entries we've already processed to prevent duplicates within this sync
        var processedKeys = Set<String>()
        let calendar = Calendar.current

        // Build keys for existing local entries
        for entry in localEntries {
            let day = calendar.startOfDay(for: entry.date).timeIntervalSince1970
            let key = "\(entry.title)-\(entry.mediaTypeRaw)-\(day)"
            processedKeys.insert(key)
        }

        for cloudEntry in cloudEntries {
            // Skip entries that were recently deleted locally
            if let entryUUID = UUID(uuidString: cloudEntry.localId),
               DeletionTracker.shared.isMediaEntryDeleted(entryUUID) {
                entrySyncLogger.info("Skipping deleted media entry: \(cloudEntry.localId)")
                continue
            }

            // Parse cloud entry date for comparison
            let cloudDate = cloudEntry.date.flatMap { ISO8601DateFormatter().date(from: $0) }

            // First try to match by ID
            if let existingEntry = localEntries.first(where: { $0.id.uuidString == cloudEntry.localId }) {
                // Update if cloud is newer
                if let cloudUpdatedAt = ISO8601DateFormatter().date(from: cloudEntry.updatedAt),
                   cloudUpdatedAt > existingEntry.updatedAt {
                    existingEntry.title = cloudEntry.title
                    existingEntry.mediaTypeRaw = cloudEntry.mediaTypeRaw
                    existingEntry.videoTypeRaw = cloudEntry.videoTypeRaw
                    if let date = cloudDate {
                        existingEntry.date = date
                    }
                    if let endDateStr = cloudEntry.endDate {
                        existingEntry.endDate = ISO8601DateFormatter().date(from: endDateStr)
                    }
                    existingEntry.imageURL = cloudEntry.imageURL
                    existingEntry.rating = cloudEntry.rating
                    existingEntry.notes = cloudEntry.notes
                    existingEntry.updatedAt = cloudUpdatedAt
                }
            } else {
                // Build key for this cloud entry
                let cloudDay = cloudDate.map { calendar.startOfDay(for: $0).timeIntervalSince1970 } ?? 0
                let cloudKey = "\(cloudEntry.title)-\(cloudEntry.mediaTypeRaw)-\(cloudDay)"

                // Check if we've already processed this entry
                if processedKeys.contains(cloudKey) {
                    entrySyncLogger.info("Skipping duplicate media entry: \(cloudEntry.title) on \(cloudEntry.date ?? "unknown")")
                    continue
                }

                // Mark as processed
                processedKeys.insert(cloudKey)

                // Create new entry from cloud
                let mediaType = MediaType(rawValue: cloudEntry.mediaTypeRaw) ?? .movies
                let videoType = cloudEntry.videoTypeRaw.flatMap { VideoType(rawValue: $0) }
                let date = cloudDate ?? Date()
                let endDate = cloudEntry.endDate.flatMap { ISO8601DateFormatter().date(from: $0) }

                let newEntry = MediaEntry(
                    id: UUID(uuidString: cloudEntry.localId) ?? UUID(),
                    title: cloudEntry.title,
                    mediaType: mediaType,
                    videoType: videoType,
                    date: date,
                    endDate: endDate,
                    imageURL: cloudEntry.imageURL,
                    rating: cloudEntry.rating,
                    notes: cloudEntry.notes,
                    user: user
                )
                if let cloudUpdatedAt = ISO8601DateFormatter().date(from: cloudEntry.updatedAt) {
                    newEntry.updatedAt = cloudUpdatedAt
                }
                context.insert(newEntry)
            }
        }

        try context.save()
    }

    @MainActor
    func mergeCustomEntries(_ cloudEntries: [CloudCustomEntry], into context: ModelContext, section: CustomSection) throws {
        // Query ALL local custom entries to build the processed keys set
        // This ensures we don't create duplicates even if section.entries isn't fully loaded
        let fetchDescriptor = FetchDescriptor<CustomEntry>()
        let allLocalEntries = (try? context.fetch(fetchDescriptor)) ?? []

        // Track entries we've already processed to prevent duplicates within this sync
        var processedKeys = Set<String>()

        // Build keys for ALL existing local entries (not just this section)
        let calendar = Calendar.current
        entrySyncLogger.notice("Merging \(cloudEntries.count) cloud entries, total local entries: \(allLocalEntries.count)")

        for entry in allLocalEntries {
            let hour = entry.startTime.map { calendar.component(.hour, from: $0) } ?? -1
            let minute = entry.startTime.map { calendar.component(.minute, from: $0) } ?? -1
            let day = calendar.startOfDay(for: entry.date).timeIntervalSince1970
            let key = "\(entry.title)-\(day)-\(hour)-\(minute)"
            processedKeys.insert(key)
        }

        entrySyncLogger.notice("Built \(processedKeys.count) keys from \(allLocalEntries.count) local entries")

        for cloudEntry in cloudEntries {
            // Skip entries that were recently deleted locally
            if let entryUUID = UUID(uuidString: cloudEntry.localId),
               DeletionTracker.shared.isCustomEntryDeleted(entryUUID) {
                entrySyncLogger.info("Skipping deleted custom entry: \(cloudEntry.localId)")
                continue
            }

            // Parse cloud entry dates for comparison
            let cloudDate = cloudEntry.date.flatMap { ISO8601DateFormatter().date(from: $0) }
            let cloudStartTime = cloudEntry.startTime.flatMap { ISO8601DateFormatter().date(from: $0) }

            // First try to match by ID (check all local entries, not just this section)
            if let existingEntry = allLocalEntries.first(where: { $0.id.uuidString == cloudEntry.localId }) {
                // Update if cloud is newer
                if let cloudDate = ISO8601DateFormatter().date(from: cloudEntry.updatedAt),
                   cloudDate > existingEntry.updatedAt {
                    existingEntry.title = cloudEntry.title
                    if let dateStr = cloudEntry.date {
                        existingEntry.date = ISO8601DateFormatter().date(from: dateStr) ?? existingEntry.date
                    }
                    if let endDateStr = cloudEntry.endDate {
                        existingEntry.endDate = ISO8601DateFormatter().date(from: endDateStr)
                    }
                    if let startTimeStr = cloudEntry.startTime {
                        existingEntry.startTime = ISO8601DateFormatter().date(from: startTimeStr)
                    }
                    if let endTimeStr = cloudEntry.endTime {
                        existingEntry.endTime = ISO8601DateFormatter().date(from: endTimeStr)
                    }
                    existingEntry.notifyBefore = cloudEntry.notifyBefore
                    existingEntry.rating = cloudEntry.rating
                    existingEntry.notes = cloudEntry.notes
                    // Recurrence
                    if let groupIdStr = cloudEntry.recurrenceGroupId {
                        existingEntry.recurrenceGroupId = UUID(uuidString: groupIdStr)
                    }
                    existingEntry.recurrencePatternRaw = cloudEntry.recurrencePatternRaw
                    existingEntry.recurrenceWeekdays = cloudEntry.recurrenceWeekdays
                    if let endDateStr = cloudEntry.recurrenceEndDate {
                        existingEntry.recurrenceEndDate = ISO8601DateFormatter().date(from: endDateStr)
                    }
                    existingEntry.recurrenceOccurrenceCount = cloudEntry.recurrenceOccurrenceCount
                    existingEntry.isRecurrenceTemplate = cloudEntry.isRecurrenceTemplate
                    existingEntry.updatedAt = cloudDate
                }
            } else {
                // Build key for this cloud entry
                let cloudHour = cloudStartTime.map { calendar.component(.hour, from: $0) } ?? -1
                let cloudMinute = cloudStartTime.map { calendar.component(.minute, from: $0) } ?? -1
                let cloudDay = cloudDate.map { calendar.startOfDay(for: $0).timeIntervalSince1970 } ?? 0
                let cloudKey = "\(cloudEntry.title)-\(cloudDay)-\(cloudHour)-\(cloudMinute)"

                // Check if we've already processed this entry (either existed or created in this sync)
                if processedKeys.contains(cloudKey) {
                    entrySyncLogger.info("Skipping duplicate custom entry: \(cloudEntry.title) on \(cloudEntry.date ?? "unknown")")
                    continue
                }

                // Mark as processed
                processedKeys.insert(cloudKey)

                // Create new entry from cloud
                let date = cloudDate ?? Date()
                let endDate = cloudEntry.endDate.flatMap { ISO8601DateFormatter().date(from: $0) }
                let startTime = cloudStartTime
                let endTime = cloudEntry.endTime.flatMap { ISO8601DateFormatter().date(from: $0) }
                let recurrenceGroupId = cloudEntry.recurrenceGroupId.flatMap { UUID(uuidString: $0) }
                let recurrencePattern = cloudEntry.recurrencePatternRaw.flatMap { RecurrencePattern(rawValue: $0) }
                let recurrenceEndDate = cloudEntry.recurrenceEndDate.flatMap { ISO8601DateFormatter().date(from: $0) }

                let newEntry = CustomEntry(
                    id: UUID(uuidString: cloudEntry.localId) ?? UUID(),
                    title: cloudEntry.title,
                    date: date,
                    endDate: endDate,
                    startTime: startTime,
                    endTime: endTime,
                    notifyBefore: cloudEntry.notifyBefore,
                    rating: cloudEntry.rating,
                    notes: cloudEntry.notes,
                    section: section,
                    user: section.user,
                    recurrenceGroupId: recurrenceGroupId,
                    recurrencePattern: recurrencePattern,
                    recurrenceWeekdays: cloudEntry.recurrenceWeekdays,
                    recurrenceEndDate: recurrenceEndDate,
                    recurrenceOccurrenceCount: cloudEntry.recurrenceOccurrenceCount,
                    isRecurrenceTemplate: cloudEntry.isRecurrenceTemplate
                )
                if let cloudUpdatedAt = ISO8601DateFormatter().date(from: cloudEntry.updatedAt) {
                    newEntry.updatedAt = cloudUpdatedAt
                }
                context.insert(newEntry)
            }
        }

        try context.save()
    }

    // MARK: - Full Sync

    @MainActor
    func performFullSync(context: ModelContext, user: User) async throws {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        // 1. Sync sections
        // Fetch cloud sections
        let cloudSections = try await fetchSectionsFromCloud(userId: user.id)
        // Merge cloud → local
        try mergeSections(cloudSections, into: context, user: user)
        // Upload local → cloud
        try await syncSectionsToCloud(sections: user.customSections, userId: user.id)

        // 2. Sync media entries
        let cloudMediaEntries = try await fetchMediaEntriesFromCloud(userId: user.id)
        try mergeMediaEntries(cloudMediaEntries, into: context, user: user)
        try await syncMediaEntriesToCloud(entries: user.entries, userId: user.id)

        // 3. Sync custom entries for each section
        for section in user.customSections {
            let cloudCustomEntries = try await fetchCustomEntriesFromCloud(sectionId: section.id)
            try mergeCustomEntries(cloudCustomEntries, into: context, section: section)
            try await syncCustomEntriesToCloud(entries: section.entries)
        }

    }

    // MARK: - Delete from Cloud

    func deleteSectionFromCloud(sectionId: UUID) async throws {
        let deleteStep = InstantDBService.shared.deleteStep(
            namespace: "customSections",
            id: sectionId.uuidString
        )
        try await InstantDBService.shared.transact([deleteStep])
    }

    func deleteMediaEntryFromCloud(entryId: UUID) async throws {
        let deleteStep = InstantDBService.shared.deleteStep(
            namespace: "mediaEntries",
            id: entryId.uuidString
        )
        try await InstantDBService.shared.transact([deleteStep])
    }

    func deleteCustomEntryFromCloud(entryId: UUID) async throws {
        let deleteStep = InstantDBService.shared.deleteStep(
            namespace: "customEntries",
            id: entryId.uuidString
        )
        try await InstantDBService.shared.transact([deleteStep])
    }

    // MARK: - Cloud Cleanup

    /// Remove duplicate entries from the cloud database
    /// Keeps the first entry for each unique (section, title, date, startTime) combination
    func cleanupCloudDuplicates() async throws -> Int {
        guard AuthState.shared.isAuthenticated else {
            throw EntrySyncError.notAuthenticated
        }

        entrySyncLogger.notice("Starting cloud duplicate cleanup...")

        // Fetch all custom entries from cloud with section info
        let query: [String: Any] = [
            "customEntries": [
                "section": [String: Any]()
            ]
        ]
        let response: CustomEntriesWithSectionResponse = try await InstantDBService.shared.query(query)
        let cloudEntries = response.customEntries

        entrySyncLogger.notice("Fetched \(cloudEntries.count) entries from cloud")

        // Group entries by content key (section + title + date + startTime)
        let calendar = Calendar.current
        var groupedEntries: [String: [CloudCustomEntryWithSection]] = [:]

        for entry in cloudEntries {
            let cloudDate = entry.date.flatMap { ISO8601DateFormatter().date(from: $0) }
            let cloudStartTime = entry.startTime.flatMap { ISO8601DateFormatter().date(from: $0) }

            let cloudHour = cloudStartTime.map { calendar.component(.hour, from: $0) } ?? -1
            let cloudMinute = cloudStartTime.map { calendar.component(.minute, from: $0) } ?? -1
            let cloudDay = cloudDate.map { calendar.startOfDay(for: $0).timeIntervalSince1970 } ?? 0
            let sectionId = entry.section?.localId ?? "unknown"

            let key = "\(sectionId)-\(entry.title)-\(cloudDay)-\(cloudHour)-\(cloudMinute)"

            if groupedEntries[key] == nil {
                groupedEntries[key] = []
            }
            groupedEntries[key]?.append(entry)
        }

        // Find duplicates and create delete steps
        var deleteSteps: [[Any]] = []
        var duplicateCount = 0

        for (key, entries) in groupedEntries {
            if entries.count > 1 {
                entrySyncLogger.notice("Found \(entries.count) duplicates for key: \(key)")
                // Keep the first entry, delete the rest
                for entry in entries.dropFirst() {
                    let step = InstantDBService.shared.deleteStep(
                        namespace: "customEntries",
                        id: entry.id
                    )
                    deleteSteps.append(step)
                    duplicateCount += 1
                }
            }
        }

        if deleteSteps.isEmpty {
            entrySyncLogger.notice("No duplicates found in cloud")
            return 0
        }

        entrySyncLogger.notice("Deleting \(duplicateCount) duplicate entries from cloud...")

        // Execute delete transaction in batches (max 100 per batch to avoid timeouts)
        let batchSize = 100
        for i in stride(from: 0, to: deleteSteps.count, by: batchSize) {
            let batch = Array(deleteSteps[i..<min(i + batchSize, deleteSteps.count)])
            try await InstantDBService.shared.transact(batch)
            entrySyncLogger.notice("Deleted batch \(i / batchSize + 1)")
        }

        entrySyncLogger.notice("Cloud cleanup complete. Removed \(duplicateCount) duplicates.")
        return duplicateCount
    }
}

// MARK: - Response Models

struct CustomSectionsResponse: Decodable {
    let customSections: [CloudCustomSection]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customSections = (try? container.decode([CloudCustomSection].self, forKey: .customSections)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case customSections
    }
}

struct CloudCustomSection: Decodable {
    let id: String
    let localId: String
    let name: String
    let icon: String
    let sortOrder: Int
    let suggestedActivities: [String]
    let notificationsEnabled: Bool
    let updatedAt: String

    init(id: String, localId: String, name: String, icon: String, sortOrder: Int,
         suggestedActivities: [String], notificationsEnabled: Bool, updatedAt: String) {
        self.id = id
        self.localId = localId
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.suggestedActivities = suggestedActivities
        self.notificationsEnabled = notificationsEnabled
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.name = try container.decode(String.self, forKey: .name)
        self.icon = (try? container.decode(String.self, forKey: .icon)) ?? "star.fill"
        self.sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
        self.suggestedActivities = (try? container.decode([String].self, forKey: .suggestedActivities)) ?? []
        self.notificationsEnabled = (try? container.decode(Bool.self, forKey: .notificationsEnabled)) ?? false
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, name, icon, sortOrder, suggestedActivities, notificationsEnabled, updatedAt
    }
}

struct MediaEntriesResponse: Decodable {
    let mediaEntries: [CloudMediaEntry]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mediaEntries = (try? container.decode([CloudMediaEntry].self, forKey: .mediaEntries)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case mediaEntries
    }
}

struct CloudMediaEntry: Decodable {
    let id: String
    let localId: String
    let title: String
    let mediaTypeRaw: String
    let videoTypeRaw: String?
    let date: String?
    let endDate: String?
    let imageURL: String?
    let rating: Int?
    let notes: String?
    let updatedAt: String

    init(id: String, localId: String, title: String, mediaTypeRaw: String, videoTypeRaw: String?,
         date: String?, endDate: String?, imageURL: String?, rating: Int?, notes: String?, updatedAt: String) {
        self.id = id
        self.localId = localId
        self.title = title
        self.mediaTypeRaw = mediaTypeRaw
        self.videoTypeRaw = videoTypeRaw
        self.date = date
        self.endDate = endDate
        self.imageURL = imageURL
        self.rating = rating
        self.notes = notes
        self.updatedAt = updatedAt
    }
}

struct CustomEntriesResponse: Decodable {
    let customEntries: [CloudCustomEntry]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customEntries = (try? container.decode([CloudCustomEntry].self, forKey: .customEntries)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case customEntries
    }
}

struct CloudCustomEntry: Decodable {
    let id: String
    let localId: String
    let title: String
    let date: String?
    let endDate: String?
    let startTime: String?
    let endTime: String?
    let notifyBefore: Bool
    let rating: Int?
    let notes: String?
    let recurrenceGroupId: String?
    let recurrencePatternRaw: String?
    let recurrenceWeekdays: [Int]?
    let recurrenceEndDate: String?
    let recurrenceOccurrenceCount: Int?
    let isRecurrenceTemplate: Bool
    let updatedAt: String

    init(id: String, localId: String, title: String, date: String?, endDate: String?,
         startTime: String?, endTime: String?, notifyBefore: Bool, rating: Int?, notes: String?,
         recurrenceGroupId: String?, recurrencePatternRaw: String?, recurrenceWeekdays: [Int]?,
         recurrenceEndDate: String?, recurrenceOccurrenceCount: Int?, isRecurrenceTemplate: Bool, updatedAt: String) {
        self.id = id
        self.localId = localId
        self.title = title
        self.date = date
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.notifyBefore = notifyBefore
        self.rating = rating
        self.notes = notes
        self.recurrenceGroupId = recurrenceGroupId
        self.recurrencePatternRaw = recurrencePatternRaw
        self.recurrenceWeekdays = recurrenceWeekdays
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceOccurrenceCount = recurrenceOccurrenceCount
        self.isRecurrenceTemplate = isRecurrenceTemplate
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.title = try container.decode(String.self, forKey: .title)
        self.date = try? container.decode(String.self, forKey: .date)
        self.endDate = try? container.decode(String.self, forKey: .endDate)
        self.startTime = try? container.decode(String.self, forKey: .startTime)
        self.endTime = try? container.decode(String.self, forKey: .endTime)
        self.notifyBefore = (try? container.decode(Bool.self, forKey: .notifyBefore)) ?? false
        self.rating = try? container.decode(Int.self, forKey: .rating)
        self.notes = try? container.decode(String.self, forKey: .notes)
        self.recurrenceGroupId = try? container.decode(String.self, forKey: .recurrenceGroupId)
        self.recurrencePatternRaw = try? container.decode(String.self, forKey: .recurrencePatternRaw)
        self.recurrenceWeekdays = try? container.decode([Int].self, forKey: .recurrenceWeekdays)
        self.recurrenceEndDate = try? container.decode(String.self, forKey: .recurrenceEndDate)
        self.recurrenceOccurrenceCount = try? container.decode(Int.self, forKey: .recurrenceOccurrenceCount)
        self.isRecurrenceTemplate = (try? container.decode(Bool.self, forKey: .isRecurrenceTemplate)) ?? false
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, title, date, endDate, startTime, endTime, notifyBefore
        case rating, notes, recurrenceGroupId, recurrencePatternRaw, recurrenceWeekdays
        case recurrenceEndDate, recurrenceOccurrenceCount, isRecurrenceTemplate, updatedAt
    }
}

// MARK: - Response Models with Linked Entities

/// Linked profile reference
struct LinkedKidProfile: Decodable {
    let id: String
    let localId: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId
    }
}

/// Linked section reference
struct LinkedCustomSection: Decodable {
    let id: String
    let localId: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId
    }
}

/// Section with linked profile
struct CloudCustomSectionWithProfile: Decodable {
    let id: String
    let localId: String
    let name: String
    let icon: String
    let sortOrder: Int
    let suggestedActivities: [String]
    let notificationsEnabled: Bool
    let updatedAt: String
    let kidProfile: LinkedKidProfile?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.name = try container.decode(String.self, forKey: .name)
        self.icon = (try? container.decode(String.self, forKey: .icon)) ?? "star.fill"
        self.sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
        self.suggestedActivities = (try? container.decode([String].self, forKey: .suggestedActivities)) ?? []
        self.notificationsEnabled = (try? container.decode(Bool.self, forKey: .notificationsEnabled)) ?? false
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.kidProfile = try? container.decode(LinkedKidProfile.self, forKey: .kidProfile)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, name, icon, sortOrder, suggestedActivities, notificationsEnabled, updatedAt, kidProfile
    }

    func toCloudCustomSection() -> CloudCustomSection {
        CloudCustomSection(id: id, localId: localId, name: name, icon: icon, sortOrder: sortOrder,
                          suggestedActivities: suggestedActivities, notificationsEnabled: notificationsEnabled, updatedAt: updatedAt)
    }
}

struct CustomSectionsWithProfileResponse: Decodable {
    let customSections: [CloudCustomSectionWithProfile]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customSections = (try? container.decode([CloudCustomSectionWithProfile].self, forKey: .customSections)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case customSections
    }
}

/// Media entry with linked profile
struct CloudMediaEntryWithProfile: Decodable {
    let id: String
    let localId: String
    let title: String
    let mediaTypeRaw: String
    let videoTypeRaw: String?
    let date: String?
    let endDate: String?
    let imageURL: String?
    let rating: Int?
    let notes: String?
    let updatedAt: String
    let kidProfile: LinkedKidProfile?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.title = try container.decode(String.self, forKey: .title)
        self.mediaTypeRaw = try container.decode(String.self, forKey: .mediaTypeRaw)
        self.videoTypeRaw = try? container.decode(String.self, forKey: .videoTypeRaw)
        self.date = try? container.decode(String.self, forKey: .date)
        self.endDate = try? container.decode(String.self, forKey: .endDate)
        self.imageURL = try? container.decode(String.self, forKey: .imageURL)
        self.rating = try? container.decode(Int.self, forKey: .rating)
        self.notes = try? container.decode(String.self, forKey: .notes)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.kidProfile = try? container.decode(LinkedKidProfile.self, forKey: .kidProfile)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, title, mediaTypeRaw, videoTypeRaw, date, endDate, imageURL, rating, notes, updatedAt, kidProfile
    }

    func toCloudMediaEntry() -> CloudMediaEntry {
        CloudMediaEntry(id: id, localId: localId, title: title, mediaTypeRaw: mediaTypeRaw,
                       videoTypeRaw: videoTypeRaw, date: date, endDate: endDate, imageURL: imageURL,
                       rating: rating, notes: notes, updatedAt: updatedAt)
    }
}

struct MediaEntriesWithProfileResponse: Decodable {
    let mediaEntries: [CloudMediaEntryWithProfile]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mediaEntries = (try? container.decode([CloudMediaEntryWithProfile].self, forKey: .mediaEntries)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case mediaEntries
    }
}

/// Custom entry with linked section
struct CloudCustomEntryWithSection: Decodable {
    let id: String
    let localId: String
    let title: String
    let date: String?
    let endDate: String?
    let startTime: String?
    let endTime: String?
    let notifyBefore: Bool
    let rating: Int?
    let notes: String?
    let recurrenceGroupId: String?
    let recurrencePatternRaw: String?
    let recurrenceWeekdays: [Int]?
    let recurrenceEndDate: String?
    let recurrenceOccurrenceCount: Int?
    let isRecurrenceTemplate: Bool
    let updatedAt: String
    let section: LinkedCustomSection?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.title = try container.decode(String.self, forKey: .title)
        self.date = try? container.decode(String.self, forKey: .date)
        self.endDate = try? container.decode(String.self, forKey: .endDate)
        self.startTime = try? container.decode(String.self, forKey: .startTime)
        self.endTime = try? container.decode(String.self, forKey: .endTime)
        self.notifyBefore = (try? container.decode(Bool.self, forKey: .notifyBefore)) ?? false
        self.rating = try? container.decode(Int.self, forKey: .rating)
        self.notes = try? container.decode(String.self, forKey: .notes)
        self.recurrenceGroupId = try? container.decode(String.self, forKey: .recurrenceGroupId)
        self.recurrencePatternRaw = try? container.decode(String.self, forKey: .recurrencePatternRaw)
        self.recurrenceWeekdays = try? container.decode([Int].self, forKey: .recurrenceWeekdays)
        self.recurrenceEndDate = try? container.decode(String.self, forKey: .recurrenceEndDate)
        self.recurrenceOccurrenceCount = try? container.decode(Int.self, forKey: .recurrenceOccurrenceCount)
        self.isRecurrenceTemplate = (try? container.decode(Bool.self, forKey: .isRecurrenceTemplate)) ?? false
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.section = try? container.decode(LinkedCustomSection.self, forKey: .section)
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, title, date, endDate, startTime, endTime, notifyBefore
        case rating, notes, recurrenceGroupId, recurrencePatternRaw, recurrenceWeekdays
        case recurrenceEndDate, recurrenceOccurrenceCount, isRecurrenceTemplate, updatedAt, section
    }

    func toCloudCustomEntry() -> CloudCustomEntry {
        CloudCustomEntry(id: id, localId: localId, title: title, date: date, endDate: endDate,
                        startTime: startTime, endTime: endTime, notifyBefore: notifyBefore,
                        rating: rating, notes: notes, recurrenceGroupId: recurrenceGroupId,
                        recurrencePatternRaw: recurrencePatternRaw, recurrenceWeekdays: recurrenceWeekdays,
                        recurrenceEndDate: recurrenceEndDate, recurrenceOccurrenceCount: recurrenceOccurrenceCount,
                        isRecurrenceTemplate: isRecurrenceTemplate, updatedAt: updatedAt)
    }
}

struct CustomEntriesWithSectionResponse: Decodable {
    let customEntries: [CloudCustomEntryWithSection]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customEntries = (try? container.decode([CloudCustomEntryWithSection].self, forKey: .customEntries)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case customEntries
    }
}

// MARK: - Parent Relationship Response Models

/// Response for kidProfiles query with nested customSections
struct KidProfileWithSectionsResponse: Decodable {
    let kidProfiles: [KidProfileWithSections]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kidProfiles = (try? container.decode([KidProfileWithSections].self, forKey: .kidProfiles)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case kidProfiles
    }
}

struct KidProfileWithSections: Decodable {
    let id: String
    let localId: String
    let customSections: [CloudCustomSection]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.customSections = (try? container.decode([CloudCustomSection].self, forKey: .customSections)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, customSections
    }
}

/// Response for kidProfiles query with nested mediaEntries
struct KidProfileWithMediaEntriesResponse: Decodable {
    let kidProfiles: [KidProfileWithMediaEntries]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kidProfiles = (try? container.decode([KidProfileWithMediaEntries].self, forKey: .kidProfiles)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case kidProfiles
    }
}

struct KidProfileWithMediaEntries: Decodable {
    let id: String
    let localId: String
    let mediaEntries: [CloudMediaEntry]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.mediaEntries = (try? container.decode([CloudMediaEntry].self, forKey: .mediaEntries)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, mediaEntries
    }
}

/// Response for customSections query with nested customEntries
struct SectionWithEntriesResponse: Decodable {
    let customSections: [SectionWithEntries]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customSections = (try? container.decode([SectionWithEntries].self, forKey: .customSections)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case customSections
    }
}

struct SectionWithEntries: Decodable {
    let id: String
    let localId: String
    let customEntries: [CloudCustomEntry]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.customEntries = (try? container.decode([CloudCustomEntry].self, forKey: .customEntries)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, localId, customEntries
    }
}

// MARK: - Errors

enum EntrySyncError: Error, LocalizedError {
    case notAuthenticated
    case syncFailed
    case mergeFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to sync activities."
        case .syncFailed:
            return "Failed to sync activities. Please try again."
        case .mergeFailed:
            return "Failed to merge activities."
        }
    }
}
