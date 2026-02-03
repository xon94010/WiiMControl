import Foundation
import Observation

/// Response structure from WiiM getPlayerStatus command
struct PlayerStatus: Codable {
    let type: String?
    let ch: String?
    let mode: String?
    let loop: String?
    let eq: String?
    let status: String?
    let curpos: String?
    let offsetPts: String?
    let totlen: String?
    let title: String?
    let artist: String?
    let album: String?
    let albumArtUri: String?
    let alarmflag: String?
    let plicount: String?
    let plicurr: String?
    let vol: String?
    let mute: String?

    // Additional fields for album art
    let artwork: String?
    let albumart: String?

    enum CodingKeys: String, CodingKey {
        case type, ch, mode, loop, eq, status, curpos
        case offsetPts = "offset_pts"
        case totlen
        case title = "Title"
        case artist = "Artist"
        case album = "Album"
        case albumArtUri = "albumart_uri"
        case alarmflag, plicount, plicurr, vol, mute
        case artwork, albumart
    }

    var isPlaying: Bool {
        status == "play"
    }

    var volumeLevel: Int {
        Int(vol ?? "50") ?? 50
    }

    var isMuted: Bool {
        mute == "1"
    }

    /// Current position in seconds
    var currentPosition: Int {
        guard let curpos, let ms = Int(curpos) else { return 0 }
        return ms / 1000
    }

    /// Total duration in seconds
    var duration: Int {
        guard let totlen, let ms = Int(totlen) else { return 0 }
        return ms / 1000
    }

    var decodedTitle: String {
        guard let title else { return "" }
        return Self.decodeHexString(title) ?? title.removingPercentEncoding ?? title
    }

    var decodedArtist: String {
        guard let artist else { return "" }
        return Self.decodeHexString(artist) ?? artist.removingPercentEncoding ?? artist
    }

    var decodedAlbum: String {
        guard let album else { return "" }
        return Self.decodeHexString(album) ?? album.removingPercentEncoding ?? album
    }

    var albumArtURL: URL? {
        // Try multiple possible fields for album art
        let possibleUris = [albumArtUri, artwork, albumart].compactMap { $0 }

        for uri in possibleUris {
            guard !uri.isEmpty else { continue }
            // Decode if hex-encoded, otherwise use as-is
            let decoded = Self.decodeHexString(uri) ?? uri.removingPercentEncoding ?? uri
            if let url = URL(string: decoded) {
                return url
            }
        }
        return nil
    }

    private static func decodeHexString(_ hex: String) -> String? {
        // Check if it looks like a hex string (only hex characters)
        let hexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard hex.unicodeScalars.allSatisfy({ hexChars.contains($0) }) else {
            return nil
        }

        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let byte = UInt8(hex[index ..< nextIndex], radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        return String(bytes: bytes, encoding: .utf8)
    }
}

/// Delegate to handle self-signed SSL certificates from WiiM
class WiiMURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        // Accept self-signed certificates from WiiM device
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust
        {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// Service for communicating with WiiM Amp via HTTP API
@Observable
class WiiMService {
    private let sessionDelegate = WiiMURLSessionDelegate()
    private var _session: URLSession?

    private var session: URLSession {
        if let existing = _session {
            return existing
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        let newSession = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
        _session = newSession
        return newSession
    }

    /// Connected device IP address
    var ipAddress: String = "" {
        didSet {
            UserDefaults.standard.set(ipAddress, forKey: "wiim_ip_address")
        }
    }

    /// Connected device name
    var deviceName: String = "" {
        didSet {
            UserDefaults.standard.set(deviceName, forKey: "wiim_device_name")
        }
    }

    /// Display name for the connection
    var displayName: String {
        if ipAddress.isEmpty {
            return ""
        }
        return deviceName.isEmpty ? ipAddress : deviceName
    }

    /// Whether a device is configured
    var isConfigured: Bool {
        !ipAddress.isEmpty
    }

    init() {
        loadDevice()
    }

    private func loadDevice() {
        ipAddress = UserDefaults.standard.string(forKey: "wiim_ip_address") ?? ""
        deviceName = UserDefaults.standard.string(forKey: "wiim_device_name") ?? ""
    }

    private var baseURL: URL? {
        URL(string: "https://\(ipAddress)/httpapi.asp")
    }

    private func executeCommand(_ command: String) async throws -> Data {
        guard !ipAddress.isEmpty else {
            throw WiiMError.noIPAddress
        }

        guard let baseURL else {
            throw WiiMError.invalidURL
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "command", value: command)]

        guard let url = components.url else {
            throw WiiMError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WiiMError.networkError("Invalid response")
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw WiiMError.httpError(statusCode: httpResponse.statusCode)
            }

            return data
        } catch let urlError as URLError {
            throw WiiMError.from(urlError)
        } catch let wiimError as WiiMError {
            throw wiimError
        } catch {
            throw WiiMError.networkError(error.localizedDescription)
        }
    }

    func getPlayerStatus() async throws -> PlayerStatus {
        let data = try await executeCommand("getPlayerStatus")
        let decoder = JSONDecoder()
        return try decoder.decode(PlayerStatus.self, from: data)
    }

    /// Get possible album art URLs to try
    func getAlbumArtURLs() -> [URL] {
        guard !ipAddress.isEmpty else { return [] }
        // Try various common endpoints for album art on LinkPlay devices
        let paths = [
            "https://\(ipAddress)/data/art.jpg",
            "https://\(ipAddress)/album_art",
            "https://\(ipAddress)/httpapi.asp?command=QueryArt",
            "http://\(ipAddress):80/data/art.jpg"
        ]
        return paths.compactMap { URL(string: $0) }
    }

    /// Fetch raw data from a URL (using our SSL-trusting session)
    func fetchData(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }

    func pause() async throws {
        _ = try await executeCommand("setPlayerCmd:pause")
    }

    func resume() async throws {
        _ = try await executeCommand("setPlayerCmd:resume")
    }

    func togglePlayPause(isCurrentlyPlaying: Bool) async throws {
        if isCurrentlyPlaying {
            try await pause()
        } else {
            try await resume()
        }
    }

    func next() async throws {
        _ = try await executeCommand("setPlayerCmd:next")
    }

    func previous() async throws {
        _ = try await executeCommand("setPlayerCmd:prev")
    }

    func setVolume(_ level: Int) async throws {
        let clampedLevel = max(0, min(100, level))
        _ = try await executeCommand("setPlayerCmd:vol:\(clampedLevel)")
    }

    func setMute(_ muted: Bool) async throws {
        _ = try await executeCommand("setPlayerCmd:mute:\(muted ? 1 : 0)")
    }

    func getEQList() async throws -> [String] {
        let data = try await executeCommand("EQGetList")
        // Response is JSON array: ["Flat", "Acoustic", ...]
        if let presets = try? JSONDecoder().decode([String].self, from: data) {
            return presets
        }
        // Fallback: try as comma-separated string
        if let responseString = String(data: data, encoding: .utf8) {
            let presets = responseString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            return presets.filter { !$0.isEmpty }
        }
        return []
    }


    func loadEQPreset(_ preset: String) async throws {
        _ = try await executeCommand("EQLoad:\(preset)")
    }

    func seek(to seconds: Int) async throws {
        _ = try await executeCommand("setPlayerCmd:seek:\(seconds)")
    }

    func getPresets() async throws -> [WiiMPreset] {
        let data = try await executeCommand("getPresetInfo")
        let decoder = JSONDecoder()
        let response = try decoder.decode(PresetResponse.self, from: data)
        return response.presetList ?? []
    }

    func playPreset(_ number: Int) async throws {
        _ = try await executeCommand("MCUKeyShortClick:\(number)")
    }
}

// MARK: - Preset Models

struct PresetResponse: Codable {
    let presetNum: Int?
    let presetList: [WiiMPreset]?

    enum CodingKeys: String, CodingKey {
        case presetNum = "preset_num"
        case presetList = "preset_list"
    }
}

struct WiiMPreset: Codable, Identifiable {
    let number: Int
    let name: String?
    let url: String?
    let source: String?
    let picurl: String?

    var id: Int {
        number
    }

    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return "Preset \(number)"
    }

    var artworkURL: URL? {
        guard let picurl, !picurl.isEmpty else { return nil }
        return URL(string: picurl)
    }
}

enum WiiMError: LocalizedError {
    case noIPAddress
    case invalidURL
    case httpError(statusCode: Int)
    case networkError(String)
    case timeout
    case decodingError(String)
    case deviceUnreachable

    var errorDescription: String? {
        switch self {
        case .noIPAddress:
            "No WiiM device configured"
        case .invalidURL:
            "Invalid device URL"
        case .httpError(let statusCode):
            "Device returned error (\(statusCode))"
        case .networkError(let message):
            "Network error: \(message)"
        case .timeout:
            "Device not responding"
        case .decodingError(let message):
            "Invalid response: \(message)"
        case .deviceUnreachable:
            "Cannot reach device"
        }
    }

    /// Create from URLError
    static func from(_ urlError: URLError) -> WiiMError {
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .cannotConnectToHost, .cannotFindHost:
            return .deviceUnreachable
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkError("No internet connection")
        default:
            return .networkError(urlError.localizedDescription)
        }
    }
}
