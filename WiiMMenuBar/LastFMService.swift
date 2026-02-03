import Foundation

/// Service for fetching artist and album info from Last.fm API
class LastFMService {
    private let apiKey: String
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"

    init() {
        self.apiKey = Bundle.main.infoDictionary?["LASTFM_API_KEY"] as? String ?? ""
    }

    var isConfigured: Bool {
        !apiKey.isEmpty && !apiKey.contains("your_")
    }

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }

    /// Fetch artist biography
    func getArtistInfo(artist: String) async throws -> LastFMArtist? {
        guard isConfigured else {
            print("[Last.fm] API key not configured")
            return nil
        }

        guard let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !encodedArtist.isEmpty else { return nil }

        let urlString = "\(baseURL)?method=artist.getinfo&artist=\(encodedArtist)&api_key=\(apiKey)&format=json"
        guard let url = URL(string: urlString) else { return nil }

        print("[Last.fm] Fetching artist: \(artist)")

        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            print("[Last.fm] Response status: \(httpResponse.statusCode)")
        }

        let artistResponse = try JSONDecoder().decode(LastFMArtistResponse.self, from: data)
        return artistResponse.artist
    }

    /// Fetch album info with description
    func getAlbumInfo(artist: String, album: String) async throws -> LastFMAlbum? {
        guard isConfigured else { return nil }

        guard let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedAlbum = album.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !encodedArtist.isEmpty else { return nil }

        let urlString = "\(baseURL)?method=album.getinfo&artist=\(encodedArtist)&album=\(encodedAlbum)&api_key=\(apiKey)&format=json"
        guard let url = URL(string: urlString) else { return nil }

        print("[Last.fm] Fetching album: \(artist) - \(album)")

        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            print("[Last.fm] Response status: \(httpResponse.statusCode)")
        }

        let albumResponse = try JSONDecoder().decode(LastFMAlbumResponse.self, from: data)
        return albumResponse.album
    }

    /// Fetch track info
    func getTrackInfo(artist: String, track: String) async throws -> LastFMTrack? {
        guard isConfigured else { return nil }

        guard let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedTrack = track.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !encodedArtist.isEmpty else { return nil }

        let urlString = "\(baseURL)?method=track.getinfo&artist=\(encodedArtist)&track=\(encodedTrack)&api_key=\(apiKey)&format=json"
        guard let url = URL(string: urlString) else { return nil }

        print("[Last.fm] Fetching track: \(artist) - \(track)")

        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            print("[Last.fm] Response status: \(httpResponse.statusCode)")
        }

        let trackResponse = try JSONDecoder().decode(LastFMTrackResponse.self, from: data)
        return trackResponse.track
    }
}

// MARK: - Last.fm API Models

struct LastFMArtistResponse: Codable {
    let artist: LastFMArtist?
}

struct LastFMArtist: Codable {
    let name: String?
    let url: String?
    let bio: LastFMBio?
    let stats: LastFMStats?
    let similar: LastFMSimilar?
    let tags: LastFMTags?

    var bioSummary: String? {
        bio?.summary?.cleanHTML()
    }

    var bioContent: String? {
        bio?.content?.cleanHTML()
    }
}

struct LastFMBio: Codable {
    let summary: String?
    let content: String?
}

struct LastFMStats: Codable {
    let listeners: String?
    let playcount: String?
}

struct LastFMSimilar: Codable {
    let artist: [LastFMSimilarArtist]?
}

struct LastFMSimilarArtist: Codable {
    let name: String?
    let url: String?
}

struct LastFMTags: Codable {
    let tag: [LastFMTag]?
}

struct LastFMTag: Codable {
    let name: String?
}

struct LastFMAlbumResponse: Codable {
    let album: LastFMAlbum?
}

struct LastFMAlbum: Codable {
    let name: String?
    let artist: String?
    let url: String?
    let wiki: LastFMWiki?
    let tags: LastFMTags?
    let tracks: LastFMAlbumTracks?

    var wikiSummary: String? {
        wiki?.summary?.cleanHTML()
    }

    var wikiContent: String? {
        wiki?.content?.cleanHTML()
    }
}

struct LastFMWiki: Codable {
    let published: String?
    let summary: String?
    let content: String?
}

struct LastFMAlbumTracks: Codable {
    let track: [LastFMAlbumTrack]?
}

struct LastFMAlbumTrack: Codable {
    let name: String?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        // Duration can be int or string
        if let durationInt = try? container.decodeIfPresent(Int.self, forKey: .duration) {
            duration = durationInt
        } else if let durationString = try? container.decodeIfPresent(String.self, forKey: .duration) {
            duration = Int(durationString)
        } else {
            duration = nil
        }
    }
}

struct LastFMTrackResponse: Codable {
    let track: LastFMTrack?
}

struct LastFMTrack: Codable {
    let name: String?
    let url: String?
    let artist: LastFMTrackArtist?
    let album: LastFMTrackAlbum?
    let wiki: LastFMWiki?
    let toptags: LastFMTags?

    var wikiSummary: String? {
        wiki?.summary?.cleanHTML()
    }

    var wikiContent: String? {
        wiki?.content?.cleanHTML()
    }
}

struct LastFMTrackArtist: Codable {
    let name: String?
    let url: String?
}

struct LastFMTrackAlbum: Codable {
    let title: String?
    let artist: String?
}

// MARK: - String Extension for HTML cleaning

extension String {
    func cleanHTML() -> String {
        // Remove HTML tags
        var result = self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Trim whitespace
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
