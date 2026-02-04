import AppKit
import Foundation

/// Media source adapter that wraps WiiMService to conform to MediaSource protocol
@MainActor
final class WiiMMediaSource: MediaSource {
    private let service: WiiMService
    private var pollingTimer: Timer?
    private var lastStatus: PlayerStatus?

    private(set) var mediaInfo: MediaInfo = MediaInfo()
    private(set) var isAvailable: Bool = false

    var identifier: MediaSourceIdentifier {
        .wiim(deviceName: service.displayName)
    }

    let capabilities: MediaCapabilities = .wiimFull

    var onMediaInfoChanged: (() -> Void)?

    // WiiM-specific properties
    private(set) var presets: [WiiMPreset] = []
    private(set) var eqPresets: [String] = []
    private(set) var currentEQ: String = ""
    private(set) var volume: Int = 50
    private(set) var isMuted: Bool = false
    private(set) var albumArtImage: NSImage?
    private(set) var currentPresetArtworkURL: URL?

    init(service: WiiMService) {
        self.service = service
    }

    func startMonitoring() {
        guard service.isConfigured else { return }

        // Initial fetch
        Task {
            await fetchStatus()
            await fetchPresets()
            await fetchEQPresets()
        }

        // Poll every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchStatus()
            }
        }
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func fetchStatus() async {
        do {
            let status = try await service.getPlayerStatus()
            let oldTitle = mediaInfo.title
            let oldPlaying = mediaInfo.isPlaying

            // Update WiiM-specific state
            volume = status.volumeLevel
            isMuted = status.isMuted

            // Update media info
            mediaInfo = MediaInfo(
                title: status.decodedTitle,
                artist: status.decodedArtist,
                album: status.decodedAlbum,
                artworkData: nil,
                isPlaying: status.isPlaying,
                position: status.currentPosition,
                duration: status.duration
            )

            isAvailable = true

            // Load album art if track changed
            if oldTitle != mediaInfo.title {
                if currentPresetArtworkURL != nil, !isCurrentlyPlayingPreset() {
                    currentPresetArtworkURL = nil
                }
                await loadAlbumArt()
            }

            // Notify if changed
            if oldTitle != mediaInfo.title || oldPlaying != mediaInfo.isPlaying {
                onMediaInfoChanged?()
            }

            lastStatus = status
        } catch {
            isAvailable = false
            onMediaInfoChanged?()
        }
    }

    func togglePlayPause() async {
        do {
            try await service.togglePlayPause(isCurrentlyPlaying: mediaInfo.isPlaying)
            await fetchStatus()
        } catch {
            // Error handling
        }
    }

    func nextTrack() async {
        do {
            try await service.next()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchStatus()
        } catch {
            // Error handling
        }
    }

    func previousTrack() async {
        do {
            try await service.previous()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchStatus()
        } catch {
            // Error handling
        }
    }

    func seek(to seconds: Int) async {
        do {
            try await service.seek(to: seconds)
            mediaInfo.position = seconds
        } catch {
            // Error handling
        }
    }

    func setVolume(_ level: Int) async {
        do {
            try await service.setVolume(level)
            volume = level
        } catch {
            // Error handling
        }
    }

    // MARK: - WiiM-specific methods

    func toggleMute() async {
        do {
            try await service.setMute(!isMuted)
            isMuted = !isMuted
        } catch {
            // Error handling
        }
    }

    func fetchPresets() async {
        do {
            presets = try await service.getPresets()
        } catch {
            // Silently fail
        }
    }

    func fetchEQPresets() async {
        do {
            eqPresets = try await service.getEQList()
        } catch {
            // Silently fail
        }
    }

    func loadEQPreset(_ preset: String) async {
        do {
            try await service.loadEQPreset(preset)
            currentEQ = preset
        } catch {
            // Error handling
        }
    }

    func playPreset(_ preset: WiiMPreset) async {
        do {
            currentPresetArtworkURL = preset.artworkURL
            try await service.playPreset(preset.number)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchStatus()
            await loadAlbumArt()
        } catch {
            // Error handling
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
        guard !mediaInfo.artist.isEmpty || !mediaInfo.title.isEmpty else {
            albumArtImage = nil
            return
        }

        let searchTerm = "\(mediaInfo.artist) \(mediaInfo.title)".trimmingCharacters(in: .whitespaces)
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

    private func isCurrentlyPlayingPreset() -> Bool {
        let currentTitle = mediaInfo.title.lowercased()
        for preset in presets {
            if let presetName = preset.name?.lowercased(), !presetName.isEmpty {
                if currentTitle.contains(presetName) || presetName.contains(currentTitle) {
                    return true
                }
            }
        }
        return false
    }
}
