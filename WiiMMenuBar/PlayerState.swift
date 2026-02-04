import AppKit
import Foundation
import Observation

/// Observable model for the current player state
/// Now integrated with MediaCoordinator for unified media control
@MainActor
@Observable
class PlayerState {
    // MARK: - Public Properties (used by UI)

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

    // MARK: - Media Coordinator Integration

    /// The media coordinator managing all sources
    let coordinator: MediaCoordinator

    /// Active source identifier for display
    var activeSourceIdentifier: MediaSourceIdentifier {
        coordinator.activeSourceIdentifier
    }

    /// Whether WiiM is the active source
    var isWiiMActive: Bool {
        coordinator.isWiiMActive
    }

    /// Whether local media is the active source
    var isLocalActive: Bool {
        coordinator.isLocalActive
    }

    /// Current source mode preference
    var sourceMode: SourceMode {
        get { coordinator.sourceMode }
        set { coordinator.sourceMode = newValue }
    }

    /// Whether seeking is supported by current source
    var canSeek: Bool {
        coordinator.canSeek
    }

    /// Whether volume control is supported
    var canControlVolume: Bool {
        coordinator.canControlVolume
    }

    /// Whether presets are available
    var hasPresets: Bool {
        coordinator.hasPresets
    }

    /// Whether EQ is available
    var hasEQ: Bool {
        coordinator.hasEQ
    }

    /// App icon for the active source (for local media apps)
    var sourceAppIcon: NSImage? {
        coordinator.local.appIcon
    }

    // MARK: - Private Properties

    private let service: WiiMService
    private let discogsService = DiscogsService()
    private let lastFMService = LastFMService()
    private var lastLinerNotesQuery: String = ""

    // MARK: - Initialization

    init(service: WiiMService, coordinator: MediaCoordinator) {
        self.service = service
        self.coordinator = coordinator

        // Set up coordinator callbacks
        coordinator.onActiveSourceChanged = { [weak self] in
            Task { @MainActor in
                self?.syncFromActiveSource()
            }
        }

        // Sync when any source's media info changes
        coordinator.onMediaInfoChanged = { [weak self] in
            Task { @MainActor in
                self?.syncFromActiveSource()
            }
        }
    }

    // MARK: - Lifecycle

    func startPolling() {
        coordinator.startMonitoring()
        syncFromActiveSource()
    }

    func stopPolling() {
        coordinator.stopMonitoring()
    }

    // MARK: - State Synchronization

    /// Sync PlayerState properties from the active source
    private func syncFromActiveSource() {
        let oldTitle = title

        if isWiiMActive {
            // Sync from WiiM source
            let wiim = coordinator.wiim
            title = wiim.mediaInfo.title
            artist = wiim.mediaInfo.artist
            album = wiim.mediaInfo.album
            isPlaying = wiim.mediaInfo.isPlaying
            currentPosition = wiim.mediaInfo.position
            duration = wiim.mediaInfo.duration
            volume = wiim.volume
            isMuted = wiim.isMuted
            albumArtImage = wiim.albumArtImage
            currentPresetArtworkURL = wiim.currentPresetArtworkURL
            presets = wiim.presets
            eqPresets = wiim.eqPresets
            currentEQ = wiim.currentEQ
            isConnected = wiim.isAvailable
            errorMessage = nil
        } else {
            // Sync from local source
            let local = coordinator.local

            // If local media info is empty, trigger a fetch
            if local.mediaInfo.title.isEmpty && local.mediaInfo.artist.isEmpty {
                Task {
                    await local.refreshNowPlaying()
                    await MainActor.run {
                        syncFromActiveSource()
                    }
                }
                return
            }

            title = local.mediaInfo.title
            artist = local.mediaInfo.artist
            album = local.mediaInfo.album
            isPlaying = local.mediaInfo.isPlaying
            currentPosition = local.mediaInfo.position
            duration = local.mediaInfo.duration
            // Use system volume for local media
            local.refreshSystemVolume()
            volume = local.systemVolume
            isMuted = local.isMuted
            // Use artwork data from local if available
            if let artworkData = local.mediaInfo.artworkData {
                albumArtImage = NSImage(data: artworkData)
            } else {
                // Fall back to iTunes lookup for local media
                Task {
                    await loadAlbumArtFromiTunes()
                }
            }
            currentPresetArtworkURL = nil
            presets = []
            eqPresets = []
            currentEQ = ""
            isConnected = local.isAvailable || local.mediaInfo.hasContent
            errorMessage = nil
        }

        // Clear liner notes if track changed
        if oldTitle != title {
            clearLinerNotes()
        }
    }

    // MARK: - Playback Commands (routed through coordinator)

    func togglePlayPause() async {
        await coordinator.togglePlayPause()
        syncFromActiveSource()
    }

    func nextTrack() async {
        await coordinator.nextTrack()
        syncFromActiveSource()
    }

    func previousTrack() async {
        await coordinator.previousTrack()
        syncFromActiveSource()
    }

    func setVolume(_ level: Int) async {
        guard canControlVolume else { return }
        await coordinator.setVolume(level)
        volume = level
    }

    func toggleMute() async {
        guard canControlVolume else { return }
        if isWiiMActive {
            await coordinator.wiim.toggleMute()
            isMuted = coordinator.wiim.isMuted
        } else {
            await coordinator.local.toggleMute()
            isMuted = coordinator.local.isMuted
        }
    }

    func seek(to seconds: Int) async {
        guard canSeek else { return }
        await coordinator.seek(to: seconds)
        currentPosition = seconds
    }

    // MARK: - WiiM-specific Commands

    func fetchPresets() async {
        guard isWiiMActive else { return }
        await coordinator.wiim.fetchPresets()
        presets = coordinator.wiim.presets
    }

    func fetchEQPresets() async {
        guard isWiiMActive else { return }
        await coordinator.wiim.fetchEQPresets()
        eqPresets = coordinator.wiim.eqPresets
    }

    func loadEQPreset(_ preset: String) async {
        guard isWiiMActive else { return }
        await coordinator.wiim.loadEQPreset(preset)
        currentEQ = coordinator.wiim.currentEQ
    }

    func playPreset(_ preset: WiiMPreset) async {
        guard isWiiMActive else { return }
        await coordinator.wiim.playPreset(preset)
        syncFromActiveSource()
    }

    // MARK: - Album Art

    private func loadAlbumArtFromiTunes() async {
        guard !artist.isEmpty || !title.isEmpty else {
            albumArtImage = nil
            return
        }

        let searchTerm = "\(artist) \(title)".trimmingCharacters(in: .whitespaces)
        guard let encodedSearch = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedSearch)&media=music&limit=1")
        else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

            if let artworkUrl = response.results.first?.artworkUrl100 {
                let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                if let imageUrl = URL(string: highResUrl) {
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    albumArtImage = NSImage(data: imageData)
                }
            }
        } catch {
            // Failed to load from iTunes
        }
    }

    // MARK: - Computed Properties

    var nowPlayingText: String {
        if !isConnected && isWiiMActive {
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

    // MARK: - Liner Notes

    func fetchLinerNotes() async {
        guard !artist.isEmpty || !title.isEmpty else {
            linerNotes = nil
            artistInfo = nil
            albumInfo = nil
            linerNotesError = "No track information available"
            return
        }

        let albumQuery = album.isEmpty ? title : album
        let query = "\(artist) \(albumQuery)"

        if query == lastLinerNotesQuery && (linerNotes != nil || artistInfo != nil) {
            return
        }

        lastLinerNotesQuery = query
        isLoadingLinerNotes = true
        linerNotesError = nil

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
