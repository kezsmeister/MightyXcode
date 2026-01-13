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
}
