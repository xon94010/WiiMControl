import AppKit
import Foundation

/// Media source for controlling local macOS media players via MediaRemote framework
@MainActor
final class LocalMediaSource: MediaSource {
    private(set) var identifier: MediaSourceIdentifier = .unknown(bundleId: "unknown")
    private(set) var mediaInfo: MediaInfo = MediaInfo()
    private(set) var isAvailable: Bool = false
    private(set) var appIcon: NSImage?
    private(set) var systemVolume: Int = 50
    private(set) var isMuted: Bool = false

    let capabilities: MediaCapabilities = .localMediaWithVolume

    var onMediaInfoChanged: (() -> Void)?

    private var notificationObservers: [NSObjectProtocol] = []
    private var pollingTimer: Timer?
    private let mediaRemote = MediaRemoteBridge()

    init() {}

    func startMonitoring() {
        // Register for MediaRemote notifications
        mediaRemote.registerForNotifications()

        // Observe now playing changes
        let infoObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNowPlayingInfo()
            }
        }
        notificationObservers.append(infoObserver)

        let appObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNowPlayingInfo()
            }
        }
        notificationObservers.append(appObserver)

        let playingObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNowPlayingInfo()
            }
        }
        notificationObservers.append(playingObserver)

        // Poll periodically as backup (notifications aren't always reliable)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNowPlayingInfo()
            }
        }

        // Initial fetch
        Task {
            await fetchNowPlayingInfo()
        }

        // Get initial system volume
        refreshSystemVolume()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil

        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        mediaRemote.unregisterForNotifications()
    }

    private func fetchNowPlayingInfo() async {
        var info = await mediaRemote.getNowPlayingInfo()
        var usedAppleScriptFallback = false

        // If MediaRemote returns empty, try AppleScript fallback for Spotify
        if info.isEmpty {
            if let spotifyInfo = getSpotifyInfoViaAppleScript() {
                info = spotifyInfo
                usedAppleScriptFallback = true
            }
        }

        let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double).map { Int($0) } ?? 0
        let elapsedTime = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double).map { Int($0) } ?? 0
        let playbackRate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
        let isPlaying = playbackRate > 0

        let oldInfo = mediaInfo
        let oldIdentifier = identifier

        // Only use MediaRemote for app info if we didn't use AppleScript fallback
        if !usedAppleScriptFallback {
            let (bundleId, icon) = await mediaRemote.getNowPlayingAppInfo()
            identifier = MediaSourceIdentifier.from(bundleId: bundleId, title: title)
            appIcon = icon
        }
        // identifier and appIcon are already set by AppleScript fallback

        isAvailable = !title.isEmpty || !artist.isEmpty

        mediaInfo = MediaInfo(
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            isPlaying: isPlaying,
            position: elapsedTime,
            duration: duration
        )

        // Notify if changed
        if oldInfo.title != mediaInfo.title ||
            oldInfo.artist != mediaInfo.artist ||
            oldInfo.isPlaying != mediaInfo.isPlaying ||
            oldIdentifier != identifier
        {
            onMediaInfoChanged?()
        }
    }

    func togglePlayPause() async {
        mediaRemote.sendCommand(.togglePlayPause)
        // Small delay then refresh
        try? await Task.sleep(nanoseconds: 100_000_000)
        await fetchNowPlayingInfo()
    }

    func nextTrack() async {
        mediaRemote.sendCommand(.nextTrack)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await fetchNowPlayingInfo()
    }

    func previousTrack() async {
        mediaRemote.sendCommand(.previousTrack)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await fetchNowPlayingInfo()
    }

    func seek(to seconds: Int) async {
        // MediaRemote seek is not reliable for most apps, so this is a no-op
        // The UI should disable seeking for local media
    }

    func setVolume(_ level: Int) async {
        let clampedLevel = max(0, min(100, level))
        SystemVolumeControl.setVolume(clampedLevel)
        systemVolume = clampedLevel
    }

    func toggleMute() async {
        let newMuted = !isMuted
        SystemVolumeControl.setMuted(newMuted)
        isMuted = newMuted
    }

    func refreshSystemVolume() {
        systemVolume = SystemVolumeControl.getVolume()
        isMuted = SystemVolumeControl.isMuted()
    }

    func refreshNowPlaying() async {
        await fetchNowPlayingInfo()
    }

    /// AppleScript fallback for Spotify when MediaRemote doesn't work
    private func getSpotifyInfoViaAppleScript() -> [String: Any]? {
        let script = """
        tell application "System Events"
            if not (exists process "Spotify") then return ""
        end tell
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration / 1000) & "|||" & trackPosition & "|||playing"
            else if player state is paused then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration / 1000) & "|||" & trackPosition & "|||paused"
            else
                return ""
            end if
        end tell
        """

        guard let result = runAppleScriptReturning(script), !result.isEmpty else {
            return nil
        }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let isPlaying = parts[5] == "playing"

        // Update identifier and icon for Spotify
        identifier = .spotify
        if let spotifyApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first {
            appIcon = spotifyApp.icon
        }

        return [
            "kMRMediaRemoteNowPlayingInfoTitle": parts[0],
            "kMRMediaRemoteNowPlayingInfoArtist": parts[1],
            "kMRMediaRemoteNowPlayingInfoAlbum": parts[2],
            "kMRMediaRemoteNowPlayingInfoDuration": Double(parts[3]) ?? 0,
            "kMRMediaRemoteNowPlayingInfoElapsedTime": Double(parts[4]) ?? 0,
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": isPlaying ? 1.0 : 0.0
        ]
    }

    private func runAppleScriptReturning(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

/// Helper for controlling macOS system volume via AppleScript
enum SystemVolumeControl {
    static func getVolume() -> Int {
        let script = "output volume of (get volume settings)"
        guard let result = runAppleScript(script) else { return 50 }
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 50
    }

    static func setVolume(_ level: Int) {
        let script = "set volume output volume \(level)"
        _ = runAppleScript(script)
    }

    static func isMuted() -> Bool {
        let script = "output muted of (get volume settings)"
        guard let result = runAppleScript(script) else { return false }
        return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    static func setMuted(_ muted: Bool) {
        let script = "set volume output muted \(muted)"
        _ = runAppleScript(script)
    }

    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

/// Bridge to MediaRemote framework using dlopen/dlsym
final class MediaRemoteBridge: @unchecked Sendable {
    private var handle: UnsafeMutableRawPointer?

    // Function types
    private typealias RegisterFunc = @convention(c) (DispatchQueue) -> Void
    private typealias UnregisterFunc = @convention(c) () -> Void
    private typealias GetInfoFunc = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
    private typealias GetPIDFunc = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    private typealias SendCommandFunc = @convention(c) (Int, NSDictionary?) -> Bool

    private var registerFunc: RegisterFunc?
    private var unregisterFunc: UnregisterFunc?
    private var getNowPlayingInfoFunc: GetInfoFunc?
    private var getNowPlayingAppPIDFunc: GetPIDFunc?
    private var sendCommandFunc: SendCommandFunc?

    enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
    }

    init() {
        loadFramework()
    }

    private func loadFramework() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        guard handle != nil else {
            print("[LocalMediaSource] Failed to load MediaRemote framework: \(String(cString: dlerror()))")
            return
        }
        print("[LocalMediaSource] MediaRemote framework loaded successfully")

        registerFunc = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
            to: RegisterFunc?.self
        )
        unregisterFunc = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteUnregisterForNowPlayingNotifications"),
            to: UnregisterFunc?.self
        )
        getNowPlayingInfoFunc = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
            to: GetInfoFunc?.self
        )
        getNowPlayingAppPIDFunc = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID"),
            to: GetPIDFunc?.self
        )
        sendCommandFunc = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteSendCommand"),
            to: SendCommandFunc?.self
        )
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }

    func registerForNotifications() {
        registerFunc?(DispatchQueue.main)
    }

    func unregisterForNotifications() {
        unregisterFunc?()
    }

    func getNowPlayingInfo() async -> [String: Any] {
        await withCheckedContinuation { continuation in
            guard let getInfo = getNowPlayingInfoFunc else {
                print("[MediaRemoteBridge] getNowPlayingInfoFunc is nil")
                continuation.resume(returning: [:])
                return
            }

            getInfo(DispatchQueue.global(qos: .userInitiated)) { info in
                print("[MediaRemoteBridge] Got callback with info: \(info?.count ?? 0) items")
                continuation.resume(returning: (info as? [String: Any]) ?? [:])
            }
        }
    }

    func getNowPlayingAppBundleId() async -> String? {
        await withCheckedContinuation { continuation in
            guard let getPID = getNowPlayingAppPIDFunc else {
                continuation.resume(returning: nil)
                return
            }

            getPID(DispatchQueue.main) { pid in
                guard pid > 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                if let app = NSRunningApplication(processIdentifier: pid) {
                    continuation.resume(returning: app.bundleIdentifier)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func getNowPlayingAppInfo() async -> (bundleId: String?, icon: NSImage?) {
        await withCheckedContinuation { continuation in
            guard let getPID = getNowPlayingAppPIDFunc else {
                continuation.resume(returning: (nil, nil))
                return
            }

            getPID(DispatchQueue.main) { pid in
                guard pid > 0 else {
                    continuation.resume(returning: (nil, nil))
                    return
                }

                if let app = NSRunningApplication(processIdentifier: pid) {
                    continuation.resume(returning: (app.bundleIdentifier, app.icon))
                } else {
                    continuation.resume(returning: (nil, nil))
                }
            }
        }
    }

    func sendCommand(_ command: Command) {
        _ = sendCommandFunc?(command.rawValue, nil)
    }
}
