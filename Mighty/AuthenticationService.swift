import Foundation
import os.log

private let authLogger = Logger(subsystem: "com.mighty.app", category: "Auth")

actor AuthenticationService {
    static let shared = AuthenticationService()

    // MARK: - Configuration

    private let proxyBaseURL = "https://mighty-auth.mighty-app.workers.dev"

    // InstantDB base URL for token verification (no admin token needed)
    private let instantDBBaseURL = "https://api.instantdb.com"

    private let appId = Secrets.instantDBAppId

    private init() {}

    // MARK: - Magic Code Flow

    func sendMagicCode(to email: String) async throws {
        let url = URL(string: "\(proxyBaseURL)/auth/send-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SendMagicCodeRequest(email: email)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "nil"
            authLogger.error("Send magic code failed: \(responseBody)")
            throw AuthError.sendCodeFailed
        }
    }

    func verifyMagicCode(email: String, code: String) async throws -> AuthResult {
        let url = URL(string: "\(proxyBaseURL)/auth/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = VerifyMagicCodeRequest(email: email, code: code)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidCode
        }

        let result = try JSONDecoder().decode(VerifyMagicCodeResponse.self, from: data)

        // Store tokens securely
        try await storeCredentials(
            refreshToken: result.user.refreshToken,
            userId: result.user.id,
            email: email
        )

        // Update auth state
        await AuthState.shared.setAuthenticated(
            email: email,
            userId: result.user.id
        )

        return AuthResult(
            userId: result.user.id,
            email: email,
            refreshToken: result.user.refreshToken
        )
    }

    // MARK: - Token Management

    func checkAuthenticationStatus() async {
        await AuthState.shared.setLoading(true)

        do {
            guard let refreshToken = try await KeychainHelper.shared.read(for: .refreshToken),
                  let userId = try await KeychainHelper.shared.read(for: .userId),
                  let email = try await KeychainHelper.shared.read(for: .userEmail) else {
                await AuthState.shared.setUnauthenticated()
                return
            }

            // Verify token with InstantDB (no admin token needed)
            let isValid = try await verifyRefreshToken(refreshToken)

            if isValid {
                await AuthState.shared.setAuthenticated(email: email, userId: userId)
            } else {
                try await logout()
            }
        } catch {
            authLogger.error("Auth check error: \(error.localizedDescription)")
            await AuthState.shared.setUnauthenticated()
        }
    }

    private func verifyRefreshToken(_ token: String) async throws -> Bool {
        let url = URL(string: "\(instantDBBaseURL)/runtime/auth/verify_refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "app-id": appId,
            "refresh-token": token
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                authLogger.warning("Token verification failed: Invalid response type")
                return false
            }

            let isValid = (200...299).contains(httpResponse.statusCode)
            if !isValid {
                let responseBody = String(data: data, encoding: .utf8) ?? "nil"
                authLogger.warning("Token verification failed: HTTP \(httpResponse.statusCode) - \(responseBody)")
            }
            return isValid
        } catch {
            authLogger.error("Token verification network error: \(error.localizedDescription)")
            throw error
        }
    }

    func logout() async throws {
        try await KeychainHelper.shared.clearAll()
        await AuthState.shared.setUnauthenticated()
    }

    // MARK: - Token Access

    func getRefreshToken() async throws -> String? {
        try await KeychainHelper.shared.read(for: .refreshToken)
    }

    func getUserId() async throws -> String? {
        try await KeychainHelper.shared.read(for: .userId)
    }

    // MARK: - Private Helpers

    private func storeCredentials(refreshToken: String, userId: String, email: String) async throws {
        try await KeychainHelper.shared.save(refreshToken, for: .refreshToken)
        try await KeychainHelper.shared.save(userId, for: .userId)
        try await KeychainHelper.shared.save(email, for: .userEmail)
    }
}

// MARK: - Request Models

struct SendMagicCodeRequest: Encodable {
    let email: String
}

struct VerifyMagicCodeRequest: Encodable {
    let email: String
    let code: String
}

// MARK: - Response Models

struct VerifyMagicCodeResponse: Decodable {
    let user: InstantDBUser
}

struct InstantDBUser: Decodable {
    let id: String
    let email: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case refreshToken = "refresh_token"
    }
}

// MARK: - Result Models

struct AuthResult {
    let userId: String
    let email: String
    let refreshToken: String
}

// MARK: - Errors

enum AuthError: Error, LocalizedError {
    case sendCodeFailed
    case invalidCode
    case tokenExpired
    case networkError
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .sendCodeFailed:
            return "Failed to send magic code. Please try again."
        case .invalidCode:
            return "Invalid code. Please check and try again."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .networkError:
            return "Network error. Please check your connection."
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        }
    }
}
