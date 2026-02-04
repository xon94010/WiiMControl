import AppKit
import Foundation
import Observation

/// Coordinates between WiiM and local media sources, handling auto-detection and manual selection
@MainActor
@Observable
final class MediaCoordinator {
    private let wiimSource: WiiMMediaSource
    private let localSource: LocalMediaSource

    /// User's preferred source mode
    var sourceMode: SourceMode = .auto {
        didSet {
            UserDefaults.standard.set(sourceMode.rawValue, forKey: "media_source_mode")
            updateActiveSource()
        }
    }

    /// The currently active source for commands
    private(set) var activeSource: (any MediaSource)?

    /// Identifier of the active source
    var activeSourceIdentifier: MediaSourceIdentifier {
        activeSource?.identifier ?? .wiim(deviceName: "")
    }

    /// Whether WiiM is the active source
    var isWiiMActive: Bool {
        if case .wiim = activeSourceIdentifier {
            return true
        }
        return false
    }

    /// Whether local media is the active source
    var isLocalActive: Bool {
        activeSourceIdentifier.isLocalMedia
    }

    /// Current media info from the active source
    var currentMediaInfo: MediaInfo {
        activeSource?.mediaInfo ?? MediaInfo()
    }

    /// Whether the active source supports seeking
    var canSeek: Bool {
        activeSource?.capabilities.contains(.seek) ?? false
    }

    /// Whether the active source supports volume control
    var canControlVolume: Bool {
        activeSource?.capabilities.contains(.volume) ?? false
    }

    /// Whether the active source supports presets
    var hasPresets: Bool {
        activeSource?.capabilities.contains(.presets) ?? false
    }

    /// Whether the active source supports EQ
    var hasEQ: Bool {
        activeSource?.capabilities.contains(.eq) ?? false
    }

    /// Direct access to WiiM source for WiiM-specific features
    var wiim: WiiMMediaSource {
        wiimSource
    }

    /// Direct access to local source for local-specific info
    var local: LocalMediaSource {
        localSource
    }

    /// Callback when active source changes or media info updates
    var onActiveSourceChanged: (() -> Void)?

    /// Callback when any source's media info changes (for UI updates)
    var onMediaInfoChanged: (() -> Void)?

    init(wiimService: WiiMService) {
        self.wiimSource = WiiMMediaSource(service: wiimService)
        self.localSource = LocalMediaSource()

        // Load saved preference
        if let savedMode = UserDefaults.standard.string(forKey: "media_source_mode"),
           let mode = SourceMode(rawValue: savedMode)
        {
            sourceMode = mode
        }

        // Set up internal callbacks - these should not be overwritten
        setupSourceCallbacks()
    }

    private func setupSourceCallbacks() {
        wiimSource.onMediaInfoChanged = { [weak self] in
            self?.handleSourceMediaInfoChanged()
        }
        localSource.onMediaInfoChanged = { [weak self] in
            self?.handleSourceMediaInfoChanged()
        }
    }

    private func handleSourceMediaInfoChanged() {
        updateActiveSource()
        onMediaInfoChanged?()
    }

    func startMonitoring() {
        wiimSource.startMonitoring()
        localSource.startMonitoring()
        updateActiveSource()
    }

    func stopMonitoring() {
        wiimSource.stopMonitoring()
        localSource.stopMonitoring()
    }

    /// Update which source is active based on mode and current state
    private func updateActiveSource() {
        let previousSource = activeSource?.identifier

        switch sourceMode {
        case .auto:
            activeSource = determineAutoSource()
        case .wiim:
            activeSource = wiimSource
        case .local:
            activeSource = localSource
        }

        if previousSource != activeSource?.identifier {
            onActiveSourceChanged?()
        }
    }

    /// Auto-detection logic:
    /// 1. If WiiM is playing → control WiiM
    /// 2. Else if local media is playing → control local
    /// 3. Else if WiiM is connected → control WiiM
    /// 4. Else → control local
    private func determineAutoSource() -> any MediaSource {
        // Priority 1: WiiM is actively playing
        if wiimSource.isAvailable && wiimSource.mediaInfo.isPlaying {
            return wiimSource
        }

        // Priority 2: Local media is playing
        if localSource.isAvailable && localSource.mediaInfo.isPlaying {
            return localSource
        }

        // Priority 3: WiiM is connected (even if not playing)
        if wiimSource.isAvailable {
            return wiimSource
        }

        // Priority 4: Fall back to local
        return localSource
    }

    // MARK: - Playback Commands (routed through active source)

    func togglePlayPause() async {
        await activeSource?.togglePlayPause()
    }

    func nextTrack() async {
        await activeSource?.nextTrack()
    }

    func previousTrack() async {
        await activeSource?.previousTrack()
    }

    func seek(to seconds: Int) async {
        await activeSource?.seek(to: seconds)
    }

    func setVolume(_ level: Int) async {
        await activeSource?.setVolume(level)
    }

    // MARK: - Source Selection Helpers

    /// Available sources for the picker
    var availableSources: [SourceMode] {
        SourceMode.allCases
    }

    /// Description for source mode
    func description(for mode: SourceMode) -> String {
        switch mode {
        case .auto:
            return "Automatically switch based on what's playing"
        case .wiim:
            return "Always control WiiM device"
        case .local:
            return "Always control local media apps"
        }
    }
}
