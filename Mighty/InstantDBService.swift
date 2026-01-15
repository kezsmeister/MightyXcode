import Foundation
import os.log

private let instantDBLogger = Logger(subsystem: "com.mighty.app", category: "InstantDB")

/// HTTP client for InstantDB operations via secure backend proxy
/// The admin token is kept secure on the server - only the user's refresh token is sent
actor InstantDBService {
    static let shared = InstantDBService()

    /// Base URL for the InstantDB proxy worker
    private let proxyURL = Secrets.instantDBProxyURL

    private init() {}

    // MARK: - Query

    /// Execute a query to fetch data from InstantDB via proxy
    func query<T: Decodable>(_ queryObject: [String: Any]) async throws -> T {
        guard let refreshToken = try await AuthenticationService.shared.getRefreshToken() else {
            throw InstantDBError.notAuthenticated
        }

        let url = URL(string: "\(proxyURL)/db/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "refresh_token": refreshToken,
            "query": queryObject
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData

        // Log request (without token)
        instantDBLogger.notice("Query request: \(String(describing: queryObject))")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstantDBError.networkError
        }

        // Log response
        instantDBLogger.info("Query response status: \(httpResponse.statusCode), bytes: \(data.count)")
        if let responseStr = String(data: data, encoding: .utf8) {
            instantDBLogger.info("Query response body: \(responseStr.prefix(1000))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw InstantDBError.tokenExpired
            }
            throw InstantDBError.queryFailed(httpResponse.statusCode)
        }

        // Handle empty response
        if data.isEmpty {
            instantDBLogger.info("Query returned empty response, using empty JSON")
            let emptyJson = "{}".data(using: .utf8)!
            return try JSONDecoder().decode(T.self, from: emptyJson)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Transact

    /// Execute a transaction to write data to InstantDB via proxy
    func transact(_ steps: [[Any]]) async throws {
        guard let refreshToken = try await AuthenticationService.shared.getRefreshToken() else {
            throw InstantDBError.notAuthenticated
        }

        let url = URL(string: "\(proxyURL)/db/transact")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "refresh_token": refreshToken,
            "steps": steps
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData

        // Log transact request (without token)
        instantDBLogger.notice("Transact with \(steps.count) steps")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstantDBError.networkError
        }

        // Log transact response
        instantDBLogger.info("Transact response status: \(httpResponse.statusCode), bytes: \(data.count)")
        if let responseStr = String(data: data, encoding: .utf8) {
            instantDBLogger.info("Transact response body: \(responseStr.prefix(1000))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw InstantDBError.tokenExpired
            }
            throw InstantDBError.transactFailed(httpResponse.statusCode)
        }
    }

    // MARK: - Helpers (Admin API step format)

    /// Create an "update" step for InstantDB transaction
    /// Format: ["update", "namespace", "id", { ...data }]
    nonisolated func updateStep(namespace: String, id: String, data: [String: Any]) -> [Any] {
        return ["update", namespace, id, data]
    }

    /// Create a "delete" step for InstantDB transaction
    /// Format: ["delete", "namespace", "id"]
    nonisolated func deleteStep(namespace: String, id: String) -> [Any] {
        return ["delete", namespace, id]
    }

    /// Create a "link" step for InstantDB transaction
    /// Format: ["link", "namespace", "id", { "linkField": "linkedId" }]
    nonisolated func linkStep(namespace: String, id: String, linkField: String, linkedId: String) -> [Any] {
        return ["link", namespace, id, [linkField: linkedId]]
    }

    /// Create an "unlink" step for InstantDB transaction
    /// Format: ["unlink", "namespace", "id", { "linkField": "linkedId" }]
    nonisolated func unlinkStep(namespace: String, id: String, linkField: String, linkedId: String) -> [Any] {
        return ["unlink", namespace, id, [linkField: linkedId]]
    }
}

// MARK: - Errors

enum InstantDBError: Error, LocalizedError {
    case notAuthenticated
    case networkError
    case tokenExpired
    case queryFailed(Int)
    case transactFailed(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .networkError:
            return "Network error. Please check your connection."
        case .tokenExpired:
            return "Session expired. Please sign in again."
        case .queryFailed(let code):
            return "Query failed with status \(code)."
        case .transactFailed(let code):
            return "Transaction failed with status \(code)."
        case .decodingError:
            return "Failed to parse response."
        }
    }
}
