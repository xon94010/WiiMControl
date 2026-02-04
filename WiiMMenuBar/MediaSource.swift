import AppKit
import Foundation

/// Identifies the media source type
enum MediaSourceIdentifier: Equatable, Hashable {
    case wiim(deviceName: String)
    case spotify
    case appleMusic
    case amazonMusic
    case plexAmp
    case youtube
    case browser(name: String)
    case unknown(bundleId: String)

    var displayName: String {
        switch self {
        case .wiim(let deviceName):
            return deviceName.isEmpty ? "WiiM" : deviceName
        case .spotify:
            return "Spotify"
        case .appleMusic:
            return "Apple Music"
        case .amazonMusic:
            return "Amazon Music"
        case .plexAmp:
            return "Plex Amp"
        case .youtube:
            return "YouTube"
        case .browser(let name):
            return name
        case .unknown(let bundleId):
            return bundleId.components(separatedBy: ".").last ?? bundleId
        }
    }

    var iconName: String {
        switch self {
        case .wiim:
            return "hifispeaker.fill"
        case .spotify:
            return "music.note"
        case .appleMusic:
            return "music.quarternote.3"
        case .amazonMusic:
            return "music.note.list"
        case .plexAmp:
            return "play.square.stack"
        case .youtube:
            return "play.rectangle.fill"
        case .browser:
            return "globe"
        case .unknown:
            return "music.note"
        }
    }

    var iconColor: NSColor {
        switch self {
        case .wiim:
            return .cyan
        case .spotify:
            return NSColor(red: 0.12, green: 0.84, blue: 0.38, alpha: 1.0) // Spotify green
        case .appleMusic:
            return NSColor(red: 0.98, green: 0.34, blue: 0.52, alpha: 1.0) // Apple Music pink
        case .amazonMusic:
            return NSColor(red: 0.0, green: 0.63, blue: 0.89, alpha: 1.0) // Amazon blue
        case .plexAmp:
            return NSColor(red: 0.91, green: 0.67, blue: 0.0, alpha: 1.0) // Plex orange
        case .youtube:
            return NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // YouTube red
        case .browser:
            return .systemGray
        case .unknown:
            return .systemGray
        }
    }

    /// Create identifier from bundle ID
    static func from(bundleId: String?, title: String? = nil) -> MediaSourceIdentifier {
        guard let bundleId = bundleId else {
            return .unknown(bundleId: "unknown")
        }

        switch bundleId {
        case "com.spotify.client":
            return .spotify
        case "com.apple.Music":
            return .appleMusic
        case "com.amazon.music":
            return .amazonMusic
        case "tv.plex.plexamp":
            return .plexAmp
        case let id where id.contains("safari") || id.contains("Safari"):
            // Check if it's YouTube content
            if let title = title, title.lowercased().contains("youtube") {
                return .youtube
            }
            return .browser(name: "Safari")
        case let id where id.contains("chrome") || id.contains("Chrome"):
            if let title = title, title.lowercased().contains("youtube") {
                return .youtube
            }
            return .browser(name: "Chrome")
        case let id where id.contains("firefox") || id.contains("Firefox"):
            if let title = title, title.lowercased().contains("youtube") {
                return .youtube
            }
            return .browser(name: "Firefox")
        default:
            return .unknown(bundleId: bundleId)
        }
    }

    var isLocalMedia: Bool {
        switch self {
        case .wiim:
            return false
        default:
            return true
        }
    }
}

/// Information about currently playing media
struct MediaInfo {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artworkData: Data?
    var isPlaying: Bool = false
    var position: Int = 0  // in seconds
    var duration: Int = 0  // in seconds

    var hasContent: Bool {
        !title.isEmpty || !artist.isEmpty
    }
}

/// Capabilities that a media source supports
struct MediaCapabilities: OptionSet {
    let rawValue: Int

    static let playPause = MediaCapabilities(rawValue: 1 << 0)
    static let nextTrack = MediaCapabilities(rawValue: 1 << 1)
    static let previousTrack = MediaCapabilities(rawValue: 1 << 2)
    static let seek = MediaCapabilities(rawValue: 1 << 3)
    static let volume = MediaCapabilities(rawValue: 1 << 4)
    static let presets = MediaCapabilities(rawValue: 1 << 5)
    static let eq = MediaCapabilities(rawValue: 1 << 6)

    /// Full control capabilities (WiiM)
    static let wiimFull: MediaCapabilities = [.playPause, .nextTrack, .previousTrack, .seek, .volume, .presets, .eq]

    /// Local media capabilities (no seek, no presets/EQ, but has system volume)
    static let localMedia: MediaCapabilities = [.playPause, .nextTrack, .previousTrack]

    /// Local media with system volume control
    static let localMediaWithVolume: MediaCapabilities = [.playPause, .nextTrack, .previousTrack, .volume]
}

/// User's preference for which source to control
enum SourceMode: String, CaseIterable {
    case auto = "Auto"
    case wiim = "WiiM"
    case local = "Local"
}

/// Protocol for media sources
@MainActor
protocol MediaSource: AnyObject {
    /// Unique identifier for this source
    var identifier: MediaSourceIdentifier { get }

    /// Current media information
    var mediaInfo: MediaInfo { get }

    /// Whether this source is currently available
    var isAvailable: Bool { get }

    /// What this source can do
    var capabilities: MediaCapabilities { get }

    /// Start monitoring for state changes
    func startMonitoring()

    /// Stop monitoring
    func stopMonitoring()

    /// Toggle play/pause
    func togglePlayPause() async

    /// Skip to next track
    func nextTrack() async

    /// Skip to previous track
    func previousTrack() async

    /// Seek to position (seconds)
    func seek(to seconds: Int) async

    /// Set volume (0-100)
    func setVolume(_ level: Int) async

    /// Callback when media info changes
    var onMediaInfoChanged: (() -> Void)? { get set }
}
