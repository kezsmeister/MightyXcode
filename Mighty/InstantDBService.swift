import Foundation

/// HTTP client for InstantDB API operations
/// Uses the user's refresh token for authentication
actor InstantDBService {
    static let shared = InstantDBService()

    private let baseURL = "https://api.instantdb.com"

    private let appId = "21104cf5-7e8a-4f5a-a0f2-af76939978e9"

    private init() {}

    // MARK: - Query

    /// Execute a query to fetch data from InstantDB
    func query<T: Decodable>(_ queryObject: [String: Any]) async throws -> T {
        guard let refreshToken = try await AuthenticationService.shared.getRefreshToken() else {
            throw InstantDBError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/runtime/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "app-id": appId,
            "refresh-token": refreshToken,
            "query": queryObject
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstantDBError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw InstantDBError.tokenExpired
            }
            throw InstantDBError.queryFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Transact

    /// Execute a transaction to write data to InstantDB
    func transact(_ operations: [[String: Any]]) async throws {
        guard let refreshToken = try await AuthenticationService.shared.getRefreshToken() else {
            throw InstantDBError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/runtime/transact")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "app-id": appId,
            "refresh-token": refreshToken,
            "tx-steps": operations
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstantDBError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw InstantDBError.tokenExpired
            }
            throw InstantDBError.transactFailed(httpResponse.statusCode)
        }
    }

    // MARK: - Helpers

    /// Create an "update" operation for InstantDB transaction
    nonisolated func updateOperation(namespace: String, id: String, data: [String: Any]) -> [String: Any] {
        return [
            "update": [
                namespace: [
                    id: data
                ]
            ]
        ]
    }

    /// Create a "delete" operation for InstantDB transaction
    nonisolated func deleteOperation(namespace: String, id: String) -> [String: Any] {
        return [
            "delete": [
                namespace: id
            ]
        ]
    }

    /// Create a "link" operation for InstantDB transaction
    nonisolated func linkOperation(namespace: String, id: String, linkField: String, linkedNamespace: String, linkedId: String) -> [String: Any] {
        return [
            "link": [
                namespace: [
                    id: [
                        linkField: linkedId
                    ]
                ]
            ]
        ]
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
