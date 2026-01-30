import AppKit
import Foundation
import Observation

/// Observable model for the current player state
@Observable
class PlayerState {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var albumArtImage: NSImage?
    var isPlaying: Bool = false
    var volume: Int = 50
    var isMuted: Bool = false
    var currentPosition: Int = 0 // in seconds
    var duration: Int = 0 // in seconds
    var isConnected: Bool = false
    var errorMessage: String?
    var presets: [WiiMPreset] = []
    var currentPresetArtworkURL: URL?
    var eqPresets: [String] = []
    var currentEQ: String = ""
    var linerNotes: DiscogsRelease?
    var artistInfo: LastFMArtist?
    var albumInfo: LastFMAlbum?
    var isLoadingLinerNotes: Bool = false
    var linerNotesError: String?

    private var pollingTimer: Timer?
    private let service: WiiMService
    private let discogsService = DiscogsService()
    private let lastFMService = LastFMService()
    private var lastLinerNotesQuery: String = ""

    init(service: WiiMService) {
        self.service = service
    }

    func startPolling() {
        // Poll immediately
        Task {
            await fetchStatus()
            await fetchPresets()
            await fetchEQPresets()
        }

        // Then poll every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchStatus()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func fetchStatus() async {
        do {
            let status = try await service.getPlayerStatus()
            let oldTitle = title

            title = status.decodedTitle
            artist = status.decodedArtist
            album = status.decodedAlbum
            isPlaying = status.isPlaying
            volume = status.volumeLevel
            isMuted = status.isMuted
            currentPosition = status.currentPosition
            duration = status.duration
            isConnected = true
            errorMessage = nil

            // Note: WiiM API doesn't reliably expose current EQ preset
            // currentEQ is only set when user selects via our app

            // Only reload album art if track changed
            if oldTitle != title {
                // Clear preset artwork if track changed (user switched source)
                // unless we just played a preset (handled in playPreset)
                if currentPresetArtworkURL != nil, !isCurrentlyPlayingPreset() {
                    currentPresetArtworkURL = nil
                }
                await loadAlbumArt()
                // Clear liner notes so they get refetched for new track
                clearLinerNotes()
            }
        } catch {
            isConnected = false
            if let wiimError = error as? WiiMError {
                errorMessage = wiimError.errorDescription
            } else {
                errorMessage = "Connection failed"
            }
        }
    }

    func togglePlayPause() async {
        do {
            try await service.togglePlayPause(isCurrentlyPlaying: isPlaying)
            await fetchStatus()
        } catch {
            errorMessage = "Command failed"
        }
    }

    func nextTrack() async {
        do {
            try await service.next()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchStatus()
        } catch {
            errorMessage = "Command failed"
        }
    }

    func previousTrack() async {
        do {
            try await service.previous()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchStatus()
        } catch {
            errorMessage = "Command failed"
        }
    }

    func setVolume(_ level: Int) async {
        do {
            try await service.setVolume(level)
            volume = level
        } catch {
            errorMessage = "Volume command failed"
        }
    }

    func toggleMute() async {
        do {
            try await service.setMute(!isMuted)
            isMuted = !isMuted
        } catch {
            errorMessage = "Mute command failed"
        }
    }

    func seek(to seconds: Int) async {
        do {
            try await service.seek(to: seconds)
            currentPosition = seconds
        } catch {
            errorMessage = "Seek failed"
        }
    }

    func fetchPresets() async {
        do {
            presets = try await service.getPresets()
        } catch {
            // Silently fail - presets are optional
        }
    }

    func fetchEQPresets() async {
        do {
            eqPresets = try await service.getEQList()
            // Note: WiiM API doesn't reliably return current EQ status
            // currentEQ will be set when user selects one through our app
        } catch {
            // Silently fail - EQ is optional
        }
    }

    func loadEQPreset(_ preset: String) async {
        do {
            try await service.loadEQPreset(preset)
            currentEQ = preset
        } catch {
            errorMessage = "Failed to set EQ"
        }
    }

    func playPreset(_ preset: WiiMPreset) async {
        do {
            // Store the preset artwork URL for display
            currentPresetArtworkURL = preset.artworkURL
            try await service.playPreset(preset.number)
            // Wait a bit then refresh status
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchStatus()
            // Load the preset artwork immediately
            await loadAlbumArt()
        } catch {
            errorMessage = "Failed to play preset"
        }
    }

    private func loadAlbumArt() async {
        // First, try preset artwork if available
        if let presetURL = currentPresetArtworkURL {
            if let image = await loadImage(from: presetURL) {
                albumArtImage = image
                return
            }
        }

        // Use iTunes Search API to find album art
        guard !artist.isEmpty || !title.isEmpty else {
            albumArtImage = nil
            return
        }

        let searchTerm = "\(artist) \(title)".trimmingCharacters(in: .whitespaces)
        guard let encodedSearch = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedSearch)&media=music&limit=1")
        else {
            albumArtImage = nil
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

            if let artworkUrl = response.results.first?.artworkUrl100 {
                // Get higher resolution artwork (replace 100x100 with 600x600)
                let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                if let imageUrl = URL(string: highResUrl) {
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    albumArtImage = NSImage(data: imageData)
                    return
                }
            }
        } catch {
            // Failed to load from iTunes
        }

        albumArtImage = nil
    }

    private func loadImage(from url: URL) async -> NSImage? {
        // Try HTTPS version first
        var urlToTry = url
        if url.scheme == "http" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let httpsURL = components?.url {
                urlToTry = httpsURL
            }
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: urlToTry)
            return NSImage(data: data)
        } catch {
            // HTTPS failed, try original URL
            if urlToTry != url {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    return NSImage(data: data)
                } catch {
                    return nil
                }
            }
            return nil
        }
    }

    /// Check if current playback matches a preset (by name)
    private func isCurrentlyPlayingPreset() -> Bool {
        let currentTitle = title.lowercased()
        for preset in presets {
            if let presetName = preset.name?.lowercased(), !presetName.isEmpty {
                // Check if the preset name appears in the title or vice versa
                if currentTitle.contains(presetName) || presetName.contains(currentTitle) {
                    return true
                }
            }
        }
        return false
    }

    var nowPlayingText: String {
        if !isConnected {
            return "Not Connected"
        }
        if title.isEmpty, artist.isEmpty {
            return "Not Playing"
        }
        if artist.isEmpty {
            return title
        }
        if title.isEmpty {
            return artist
        }
        return "\(artist) - \(title)"
    }

    func fetchLinerNotes() async {
        // Don't fetch if no album info
        guard !artist.isEmpty || !title.isEmpty else {
            linerNotes = nil
            artistInfo = nil
            albumInfo = nil
            linerNotesError = "No track information available"
            return
        }

        // Use album if available, otherwise use title
        let albumQuery = album.isEmpty ? title : album
        let query = "\(artist) \(albumQuery)"

        // Don't refetch if same query
        if query == lastLinerNotesQuery && (linerNotes != nil || artistInfo != nil) {
            return
        }

        lastLinerNotesQuery = query
        isLoadingLinerNotes = true
        linerNotesError = nil

        // Fetch from both services in parallel
        async let discogsResult = discogsService.searchAlbum(artist: artist, album: albumQuery)
        async let lastFMArtistResult = lastFMService.getArtistInfo(artist: artist)
        async let lastFMAlbumResult = lastFMService.getAlbumInfo(artist: artist, album: albumQuery)

        do {
            linerNotes = try await discogsResult
        } catch {
            print("[LinerNotes] Discogs error: \(error)")
            linerNotes = nil
        }

        do {
            artistInfo = try await lastFMArtistResult
        } catch {
            print("[LinerNotes] Last.fm artist error: \(error)")
            artistInfo = nil
        }

        do {
            albumInfo = try await lastFMAlbumResult
        } catch {
            print("[LinerNotes] Last.fm album error: \(error)")
            albumInfo = nil
        }

        if linerNotes == nil && artistInfo == nil && albumInfo == nil {
            linerNotesError = "No information found"
        }

        isLoadingLinerNotes = false
    }

    func clearLinerNotes() {
        linerNotes = nil
        artistInfo = nil
        albumInfo = nil
        linerNotesError = nil
        lastLinerNotesQuery = ""
    }
}

/// iTunes Search API response
struct ITunesSearchResponse: Codable {
    let results: [ITunesTrack]
}

struct ITunesTrack: Codable {
    let artworkUrl100: String?
}
