import Foundation
import os.log

private let familyLogger = Logger(subsystem: "com.mighty.app", category: "FamilySharing")

/// Service for managing family sharing - invitations, members, and permissions
actor FamilySharingService {
    static let shared = FamilySharingService()

    private let authProxyURL = Secrets.authProxyURL

    private init() {}

    // MARK: - API Helpers

    private func getRefreshToken() async throws -> String {
        guard let token = try await KeychainHelper.shared.read(for: .refreshToken) else {
            throw FamilySharingError.notAuthenticated
        }
        return token
    }

    private func makeRequest<T: Decodable>(
        endpoint: String,
        body: [String: Any]
    ) async throws -> T {
        guard let url = URL(string: "\(authProxyURL)\(endpoint)") else {
            throw FamilySharingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FamilySharingError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw FamilySharingError.notAuthenticated
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw FamilySharingError.serverError(errorResponse.error)
            }
            throw FamilySharingError.serverError("Request failed with status \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Family Members

    /// Get family members for the current user's family
    func getMembers() async throws -> FamilyMembersResponse {
        let token = try await getRefreshToken()
        familyLogger.info("Fetching family members")

        return try await makeRequest(
            endpoint: "/family/members",
            body: ["refresh_token": token]
        )
    }

    // MARK: - Invitations

    /// Send an invitation to join the family
    func sendInvitation(email: String) async throws -> FamilyInviteResponse {
        let token = try await getRefreshToken()
        familyLogger.info("Sending invitation to \(email)")

        return try await makeRequest(
            endpoint: "/family/invite",
            body: [
                "refresh_token": token,
                "email": email
            ]
        )
    }

    /// Get pending invitations for the current user's family
    func getPendingInvitations() async throws -> FamilyInvitationsResponse {
        let token = try await getRefreshToken()
        familyLogger.info("Fetching pending invitations")

        return try await makeRequest(
            endpoint: "/family/invitations",
            body: ["refresh_token": token]
        )
    }

    /// Revoke a pending invitation
    func revokeInvitation(invitationId: String) async throws {
        let token = try await getRefreshToken()
        familyLogger.info("Revoking invitation \(invitationId)")

        let _: SuccessResponse = try await makeRequest(
            endpoint: "/family/revoke-invite",
            body: [
                "refresh_token": token,
                "invitationId": invitationId
            ]
        )
    }

    /// Accept an invitation using the token from the invite link
    func acceptInvitation(token inviteToken: String) async throws -> AcceptInviteResponse {
        let refreshToken = try await getRefreshToken()
        familyLogger.info("Accepting invitation")

        return try await makeRequest(
            endpoint: "/family/accept-invite",
            body: [
                "refresh_token": refreshToken,
                "token": inviteToken
            ]
        )
    }

    // MARK: - Member Management

    /// Remove a family member
    func removeMember(memberId: String) async throws {
        let token = try await getRefreshToken()
        familyLogger.info("Removing member \(memberId)")

        let _: SuccessResponse = try await makeRequest(
            endpoint: "/family/remove-member",
            body: [
                "refresh_token": token,
                "memberId": memberId
            ]
        )
    }
}

// MARK: - Error Types

enum FamilySharingError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use family sharing"
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Response Types

private struct ErrorResponse: Codable {
    let error: String
}

private struct SuccessResponse: Codable {
    let success: Bool
}
