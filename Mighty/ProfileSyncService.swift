import Foundation
import SwiftData

/// Service for syncing kid profiles between local SwiftData and InstantDB cloud
actor ProfileSyncService {
    static let shared = ProfileSyncService()

    private init() {}

    // MARK: - Sync to Cloud

    /// Upload local kid profiles to InstantDB
    func syncProfilesToCloud(users: [User]) async throws {
        guard AuthState.shared.isAuthenticated,
              let parentUserId = AuthState.shared.instantDBUserId else {
            throw ProfileSyncError.notAuthenticated
        }

        var steps: [[Any]] = []

        for user in users {
            let profileId = user.id.uuidString
            let profileData: [String: Any] = [
                "localId": user.id.uuidString,
                "name": user.name,
                "emoji": user.emoji,
                "yearlyMovieGoal": user.yearlyMovieGoal,
                "yearlyBookGoal": user.yearlyBookGoal,
                "tabOrder": user.tabOrder,
                "enabledTemplates": user.enabledTemplates,
                "hasCompletedOnboarding": user.hasCompletedOnboarding,
                "updatedAt": ISO8601DateFormatter().string(from: Date())
            ]

            // Update profile data
            let updateStep = InstantDBService.shared.updateStep(
                namespace: "kidProfiles",
                id: profileId,
                data: profileData
            )
            steps.append(updateStep)

            // Link to parent user ($users is the built-in users namespace)
            let linkStep = InstantDBService.shared.linkStep(
                namespace: "kidProfiles",
                id: profileId,
                linkField: "parent",
                linkedId: parentUserId
            )
            steps.append(linkStep)
        }

        if !steps.isEmpty {
            try await InstantDBService.shared.transact(steps)
        }
    }

    // MARK: - Fetch from Cloud

    /// Fetch kid profiles from InstantDB for the current user
    func fetchProfilesFromCloud() async throws -> [CloudKidProfile] {
        guard AuthState.shared.isAuthenticated else {
            throw ProfileSyncError.notAuthenticated
        }

        let query: [String: Any] = [
            "kidProfiles": [
                "$": [
                    "where": [
                        "parent": AuthState.shared.instantDBUserId ?? ""
                    ]
                ]
            ]
        ]

        let response: KidProfilesResponse = try await InstantDBService.shared.query(query)
        return response.kidProfiles
    }

    // MARK: - Merge Profiles

    /// Merge cloud profiles with local profiles, creating any that don't exist locally
    @MainActor
    func mergeCloudProfiles(_ cloudProfiles: [CloudKidProfile], into context: ModelContext) throws {
        // Fetch existing local users
        let descriptor = FetchDescriptor<User>()
        let localUsers = try context.fetch(descriptor)

        for cloudProfile in cloudProfiles {
            // Skip profiles that were recently deleted locally
            if let profileUUID = UUID(uuidString: cloudProfile.localId),
               DeletionTracker.shared.isProfileDeleted(profileUUID) {
                continue
            }

            // Check if profile already exists locally by localId
            if let existingUser = localUsers.first(where: { $0.id.uuidString == cloudProfile.localId }) {
                // Update existing user if cloud is newer than local updatedAt
                if let cloudDate = ISO8601DateFormatter().date(from: cloudProfile.updatedAt),
                   cloudDate > existingUser.updatedAt {
                    existingUser.name = cloudProfile.name
                    existingUser.emoji = cloudProfile.emoji
                    existingUser.yearlyMovieGoal = cloudProfile.yearlyMovieGoal
                    existingUser.yearlyBookGoal = cloudProfile.yearlyBookGoal
                    existingUser.tabOrder = cloudProfile.tabOrder
                    existingUser.enabledTemplates = cloudProfile.enabledTemplates
                    existingUser.hasCompletedOnboarding = cloudProfile.hasCompletedOnboarding
                    existingUser.updatedAt = cloudDate  // Update local timestamp
                }
            } else {
                // Create new local user from cloud profile
                let newUser = User(
                    id: UUID(uuidString: cloudProfile.localId) ?? UUID(),
                    name: cloudProfile.name,
                    emoji: cloudProfile.emoji,
                    yearlyMovieGoal: cloudProfile.yearlyMovieGoal,
                    yearlyBookGoal: cloudProfile.yearlyBookGoal,
                    ownerId: AuthState.shared.instantDBUserId
                )
                newUser.tabOrder = cloudProfile.tabOrder
                newUser.enabledTemplates = cloudProfile.enabledTemplates
                newUser.hasCompletedOnboarding = cloudProfile.hasCompletedOnboarding
                if let cloudDate = ISO8601DateFormatter().date(from: cloudProfile.updatedAt) {
                    newUser.updatedAt = cloudDate
                }
                context.insert(newUser)
            }
        }

        try context.save()
    }

    // MARK: - Full Sync

    /// Perform a full bidirectional sync
    @MainActor
    func performFullSync(context: ModelContext) async throws {
        guard AuthState.shared.isAuthenticated else {
            throw ProfileSyncError.notAuthenticated
        }

        // 1. Fetch cloud profiles
        let cloudProfiles = try await fetchProfilesFromCloud()

        // 2. Merge cloud → local
        try mergeCloudProfiles(cloudProfiles, into: context)

        // 3. Fetch updated local users
        let descriptor = FetchDescriptor<User>()
        let localUsers = try context.fetch(descriptor)

        // 4. Upload local → cloud
        try await syncProfilesToCloud(users: localUsers)
    }

    // MARK: - Delete from Cloud

    /// Delete a kid profile from InstantDB
    func deleteProfileFromCloud(userId: UUID) async throws {
        let deleteStep = InstantDBService.shared.deleteStep(
            namespace: "kidProfiles",
            id: userId.uuidString
        )
        try await InstantDBService.shared.transact([deleteStep])
    }
}

// MARK: - Response Models

struct KidProfilesResponse: Decodable {
    let kidProfiles: [CloudKidProfile]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kidProfiles = (try? container.decode([CloudKidProfile].self, forKey: .kidProfiles)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case kidProfiles
    }
}

struct CloudKidProfile: Decodable {
    let id: String
    let localId: String
    let name: String
    let emoji: String
    let yearlyMovieGoal: Int
    let yearlyBookGoal: Int
    let tabOrder: [String]
    let enabledTemplates: [String]
    let hasCompletedOnboarding: Bool
    let updatedAt: String
}

// MARK: - Errors

enum ProfileSyncError: Error, LocalizedError {
    case notAuthenticated
    case syncFailed
    case mergeFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to sync profiles."
        case .syncFailed:
            return "Failed to sync profiles. Please try again."
        case .mergeFailed:
            return "Failed to merge profiles."
        }
    }
}
