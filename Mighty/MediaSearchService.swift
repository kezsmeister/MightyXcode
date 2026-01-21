import Foundation
import os.log

private let searchLogger = Logger(subsystem: "com.mighty.app", category: "MediaSearch")

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let imageURL: String?
    let year: String?
}

actor MediaSearchService {
    static let shared = MediaSearchService()

    private init() {}

    func searchMovies(query: String) async -> [SearchResult] {
        guard query.count >= 3 else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.omdbapi.com/?s=\(encoded)&type=movie&apikey=925eba28") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OMDbResponse.self, from: data)
            return (response.search ?? []).compactMap { item in
                // Get higher resolution poster by replacing SX300 with SX600
                let posterURL = item.poster != "N/A" ? item.poster.replacingOccurrences(of: "SX300", with: "SX600") : nil
                return SearchResult(
                    title: item.title,
                    imageURL: posterURL,
                    year: item.year
                )
            }
        } catch {
            searchLogger.error("Movie search error: \(error.localizedDescription)")
            return []
        }
    }

    func searchTVShows(query: String) async -> [SearchResult] {
        guard query.count >= 3 else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.omdbapi.com/?s=\(encoded)&type=series&apikey=925eba28") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OMDbResponse.self, from: data)
            return (response.search ?? []).compactMap { item in
                // Get higher resolution poster by replacing SX300 with SX600
                let posterURL = item.poster != "N/A" ? item.poster.replacingOccurrences(of: "SX300", with: "SX600") : nil
                return SearchResult(
                    title: item.title,
                    imageURL: posterURL,
                    year: item.year
                )
            }
        } catch {
            searchLogger.error("TV show search error: \(error.localizedDescription)")
            return []
        }
    }

    func searchBooks(query: String) async -> [SearchResult] {
        guard query.count >= 3 else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=15&fields=title,author_name,first_publish_year,cover_i") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
            return response.docs.compactMap { doc in
                // Use large cover image
                let coverURL: String? = doc.coverI.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" }
                // Include author in title for better identification
                let authorSuffix = doc.authorName?.first.map { " by \($0)" } ?? ""
                return SearchResult(
                    title: doc.title + authorSuffix,
                    imageURL: coverURL,
                    year: doc.firstPublishYear.map { String($0) }
                )
            }
        } catch {
            searchLogger.error("Book search error: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - OMDb API Response
private struct OMDbResponse: Decodable {
    let search: [OMDbItem]?

    enum CodingKeys: String, CodingKey {
        case search = "Search"
    }
}

private struct OMDbItem: Decodable {
    let title: String
    let year: String
    let poster: String

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case poster = "Poster"
    }
}

// MARK: - Open Library API Response
private struct OpenLibraryResponse: Decodable {
    let docs: [OpenLibraryDoc]
}

private struct OpenLibraryDoc: Decodable {
    let title: String
    let authorName: [String]?
    let coverI: Int?
    let firstPublishYear: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case coverI = "cover_i"
        case firstPublishYear = "first_publish_year"
    }
}
