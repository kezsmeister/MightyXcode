import Foundation
import SwiftUI

@Observable
final class AuthState {
    static let shared = AuthState()

    private(set) var isAuthenticated = false
    private(set) var isLoading = true
    private(set) var currentUserEmail: String?
    private(set) var instantDBUserId: String?
    private(set) var didSkipAuth = false  // Track if user chose to skip login

    // Family sharing context
    private(set) var viewingFamilyId: String?  // nil = viewing own family
    private(set) var viewingFamilyRole: FamilyRole?  // Role in the family being viewed
    private(set) var viewingFamilyOwnerId: String?  // Owner's InstantDB user ID

    private init() {}

    @MainActor
    func setAuthenticated(email: String, userId: String) {
        self.isAuthenticated = true
        self.currentUserEmail = email
        self.instantDBUserId = userId
        self.isLoading = false
    }

    @MainActor
    func setUnauthenticated() {
        self.isAuthenticated = false
        self.currentUserEmail = nil
        self.instantDBUserId = nil
        self.isLoading = false
    }

    @MainActor
    func setLoading(_ loading: Bool) {
        self.isLoading = loading
    }

    @MainActor
    func skipAuthentication() {
        // Allow using app without signing in (local only mode)
        self.isAuthenticated = false
        self.currentUserEmail = nil
        self.instantDBUserId = nil
        self.isLoading = false
        self.didSkipAuth = true
    }

    /// Check if user can access the app (authenticated or skipped)
    var canAccessApp: Bool {
        isAuthenticated || didSkipAuth
    }

    // MARK: - Family Sharing

    /// Whether the user can edit data (admin or viewing own family)
    var canEdit: Bool {
        // Can always edit if viewing own family (no viewingFamilyId set)
        if viewingFamilyId == nil {
            return true
        }
        // Can edit if role is admin
        return viewingFamilyRole == .admin
    }

    /// Whether currently viewing a shared family (not own family)
    var isViewingSharedFamily: Bool {
        viewingFamilyId != nil
    }

    /// The owner ID to use for queries (either own ID or shared family owner's ID)
    var effectiveOwnerId: String? {
        viewingFamilyOwnerId ?? instantDBUserId
    }

    @MainActor
    func setViewingFamily(familyId: String?, role: FamilyRole?, ownerId: String?) {
        self.viewingFamilyId = familyId
        self.viewingFamilyRole = role
        self.viewingFamilyOwnerId = ownerId
    }

    @MainActor
    func clearViewingFamily() {
        self.viewingFamilyId = nil
        self.viewingFamilyRole = nil
        self.viewingFamilyOwnerId = nil
    }
}
