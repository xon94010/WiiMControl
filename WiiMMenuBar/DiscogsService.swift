import Foundation

/// Service for fetching album information from Discogs API
class DiscogsService {
    private let consumerKey: String
    private let consumerSecret: String
    private let baseURL = "https://api.discogs.com"

    init() {
        self.consumerKey = Bundle.main.infoDictionary?["DISCOGS_CONSUMER_KEY"] as? String ?? ""
        self.consumerSecret = Bundle.main.infoDictionary?["DISCOGS_CONSUMER_SECRET"] as? String ?? ""
    }

    var isConfigured: Bool {
        !consumerKey.isEmpty && !consumerSecret.isEmpty &&
        !consumerKey.contains("your_") && !consumerSecret.contains("your_")
    }
    private let userAgent = "WiiMControl/1.0"

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }

    /// Search for an album by artist and title
    func searchAlbum(artist: String, album: String) async throws -> DiscogsRelease? {
        guard isConfigured else {
            print("[Discogs] API keys not configured")
            return nil
        }

        // Clean up search terms
        let searchQuery = "\(artist) \(album)".trimmingCharacters(in: .whitespaces)

        guard !searchQuery.isEmpty else { return nil }

        // Use URLComponents for proper encoding
        var components = URLComponents(string: "\(baseURL)/database/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "type", value: "release"),
            URLQueryItem(name: "per_page", value: "5"),
            URLQueryItem(name: "key", value: consumerKey),
            URLQueryItem(name: "secret", value: consumerSecret)
        ]

        guard let url = components?.url else {
            print("[Discogs] Invalid URL")
            return nil
        }

        print("[Discogs] Searching: \(searchQuery)")

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[Discogs] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[Discogs] Error response: \(responseString)")
                }
                return nil
            }
        }

        let searchResponse = try JSONDecoder().decode(DiscogsSearchResponse.self, from: data)
        print("[Discogs] Found \(searchResponse.results.count) results")

        // Get the first result and fetch full details
        guard let firstResult = searchResponse.results.first else {
            print("[Discogs] No results found")
            return nil
        }

        print("[Discogs] Fetching details for: \(firstResult.title)")
        return try await fetchReleaseDetails(id: firstResult.id)
    }

    /// Fetch full release details by ID
    private func fetchReleaseDetails(id: Int) async throws -> DiscogsRelease? {
        let urlString = "\(baseURL)/releases/\(id)?key=\(consumerKey)&secret=\(consumerSecret)"
        guard let url = URL(string: urlString) else {
            print("[Discogs] Invalid release URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[Discogs] Release response status: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(DiscogsRelease.self, from: data)
    }
}

// MARK: - Discogs API Models

struct DiscogsSearchResponse: Codable {
    let results: [DiscogsSearchResult]
}

struct DiscogsSearchResult: Codable {
    let id: Int
    let title: String
    let year: String?
    let thumb: String?

    enum CodingKeys: String, CodingKey {
        case id, title, year, thumb
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        thumb = try container.decodeIfPresent(String.self, forKey: .thumb)
        // Year can be string or int in API
        if let yearString = try? container.decodeIfPresent(String.self, forKey: .year) {
            year = yearString
        } else if let yearInt = try? container.decodeIfPresent(Int.self, forKey: .year) {
            year = String(yearInt)
        } else {
            year = nil
        }
    }
}

struct DiscogsRelease: Codable {
    let id: Int
    let title: String
    let year: Int?
    let artists: [DiscogsArtist]?
    let labels: [DiscogsLabel]?
    let genres: [String]?
    let styles: [String]?
    let tracklist: [DiscogsTrack]?
    let extraartists: [DiscogsExtraArtist]?
    let notes: String?
    let country: String?
    let released: String?

    var displayYear: String {
        if let year = year {
            return String(year)
        }
        return released ?? "Unknown"
    }

    var displayArtist: String {
        artists?.map { $0.name }.joined(separator: ", ") ?? "Unknown Artist"
    }

    var displayLabel: String {
        labels?.first?.name ?? "Unknown Label"
    }

    var displayGenres: String {
        let allGenres = (genres ?? []) + (styles ?? [])
        return allGenres.joined(separator: ", ")
    }

    var personnel: [String] {
        var people: [String] = []

        // Add main artists
        if let artists = artists {
            for artist in artists {
                people.append(artist.name)
            }
        }

        // Add extra artists (musicians, producers, etc.)
        if let extras = extraartists {
            for extra in extras {
                let role = extra.role ?? "Performer"
                people.append("\(extra.name) - \(role)")
            }
        }

        return people
    }
}

struct DiscogsArtist: Codable {
    let id: Int?
    let name: String
    let role: String?
}

struct DiscogsLabel: Codable {
    let id: Int?
    let name: String
    let catno: String?
}

struct DiscogsTrack: Codable {
    let position: String?
    let title: String
    let duration: String?

    var displayPosition: String {
        position ?? ""
    }

    var displayDuration: String {
        duration ?? ""
    }
}

struct DiscogsExtraArtist: Codable {
    let id: Int?
    let name: String
    let role: String?
}
