import SwiftUI

struct MenuBarView: View {
    @Bindable var service: WiiMService
    var playerState: PlayerState?
    @Bindable var discovery: DeviceDiscovery
    @Binding var isConnected: Bool
    var onDeviceSelected: (WiiMDevice) -> Void
    var onDisconnect: () -> Void

    @State private var volSlider: Double = 50
    @State private var isDraggingVolume: Bool = false
    @State private var seekSlider: Double = 0
    @State private var isDraggingSeek: Bool = false
    @State private var seekTimer: Timer?
    @State private var showPresets: Bool = false
    @State private var showEQ: Bool = false
    @State private var isMiniMode: Bool = false
    @State private var showLinerNotes: Bool = false
    @State private var showInfo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if isConnected, let playerState {
                connectedView(playerState: playerState)
            } else {
                setupView
            }
        }
        .frame(width: 260)
    }

    // MARK: - Connected View

    private func connectedView(playerState: PlayerState) -> some View {
        VStack(spacing: 0) {
            if isMiniMode {
                miniModeView(playerState: playerState)
            } else {
                fullModeView(playerState: playerState)
            }
        }
    }

    // MARK: - Mini Mode View

    private func miniModeView(playerState: PlayerState) -> some View {
        VStack(spacing: 8) {
            // Header with expand button
            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer()

                // Track info
                VStack(spacing: 1) {
                    Text(playerState.title.isEmpty ? "Not Playing" : playerState.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !playerState.artist.isEmpty {
                        Text(playerState.artist)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: { isMiniMode = false }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Expand")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Compact controls
            HStack(spacing: 20) {
                Button(action: { Task { await playerState.previousTrack() } }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { Task { await playerState.togglePlayPause() } }) {
                    Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: { Task { await playerState.nextTrack() } }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            // Volume
            HStack(spacing: 8) {
                Button(action: { Task { await playerState.toggleMute() } }) {
                    Image(systemName: playerState.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundColor(playerState.isMuted ? .red.opacity(0.8) : .white.opacity(0.4))
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                if !playerState.isMuted {
                    Slider(value: $volSlider, in: 0...100, step: 1) { editing in
                        isDraggingVolume = editing
                        if !editing {
                            Task { await playerState.setVolume(Int(volSlider)) }
                        }
                    }
                    .controlSize(.mini)
                    .tint(.white)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .onAppear {
                volSlider = Double(playerState.volume)
            }
            .onChange(of: playerState.volume) { _, newValue in
                if !isDraggingVolume {
                    volSlider = Double(newValue)
                }
            }
        }
        .background(Color.black)
    }

    // MARK: - Full Mode View

    private func fullModeView(playerState: PlayerState) -> some View {
        VStack(spacing: 0) {
            // Device name header (clickable to go to config)
            ZStack {
                Button(action: onDisconnect) {
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(playerState.isConnected ? Color(red: 0.2, green: 0.9, blue: 0.4) : .orange)
                                .frame(width: 6, height: 6)
                            Text(service.displayName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        if !playerState.currentEQ.isEmpty, !playerState.eqPresets.isEmpty,
                           playerState.eqPresets.contains(playerState.currentEQ)
                        {
                            Text("EQ: \(playerState.currentEQ)")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Change Device")

                HStack {
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: { isMiniMode = true }) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("Mini Mode")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black)

            // Controls
            VStack(spacing: 10) {
                playbackControls(playerState: playerState)
                volumeControl(playerState: playerState)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black)

            // Album art
            ZStack {
                Color.black // Black background for letterboxing

                if let nsImage = playerState.albumArtImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .contentShape(Rectangle())

            // Track info and seek bar
            VStack(spacing: 8) {
                // Track title and artist
                VStack(spacing: 2) {
                    if !playerState.title.isEmpty {
                        Text(playerState.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    if !playerState.artist.isEmpty {
                        Text(playerState.artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    if playerState.title.isEmpty, playerState.artist.isEmpty {
                        Text("Not Playing")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Seek bar (only show if we have duration)
                if playerState.duration > 0 {
                    seekBar(playerState: playerState)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.85))

            // Bottom tabs section (Presets & EQ)
            bottomTabsSection(playerState: playerState)
        }
    }

    // MARK: - Bottom Tabs Section (Presets, EQ & Info)

    private func bottomTabsSection(playerState: PlayerState) -> some View {
        VStack(spacing: 0) {
            // Tab headers
            HStack(spacing: 0) {
                // Presets tab
                VStack(spacing: 3) {
                    Text("Presets")
                        .font(.caption)
                        .foregroundColor(showPresets ? .white : .white.opacity(0.7))
                    Image(systemName: showPresets ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(showPresets ? .white.opacity(0.6) : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(showPresets ? Color.white.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if showPresets {
                        showPresets = false
                    } else {
                        showPresets = true
                        showEQ = false
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 30)

                // EQ tab
                VStack(spacing: 3) {
                    Text("EQ")
                        .font(.caption)
                        .foregroundColor(showEQ ? .white : .white.opacity(0.7))
                    Image(systemName: showEQ ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(showEQ ? .white.opacity(0.6) : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(showEQ ? Color.white.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if showEQ {
                        showEQ = false
                    } else {
                        showEQ = true
                        showPresets = false
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 30)

                // Info tab
                VStack(spacing: 3) {
                    Text("Info")
                        .font(.caption)
                        .foregroundColor(showInfo ? .white : .white.opacity(0.7))
                    Image(systemName: showInfo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(showInfo ? .white.opacity(0.6) : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(showInfo ? Color.white.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if showInfo {
                        showInfo = false
                    } else {
                        showInfo = true
                        showPresets = false
                        showEQ = false
                        Task { await playerState.fetchLinerNotes() }
                    }
                }
            }
            .background(Color.black.opacity(0.6))

            // Expandable presets list
            if !playerState.presets.isEmpty {
                VStack(spacing: 2) {
                    ForEach(playerState.presets) { preset in
                        PresetRowView(preset: preset) {
                            Task {
                                await playerState.playPreset(preset)
                                showPresets = false
                            }
                        }
                    }
                }
                .frame(height: showPresets ? nil : 0, alignment: .top)
                .clipped()
                .opacity(showPresets ? 1 : 0)
            }

            // Expandable EQ list (scrollable)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(playerState.eqPresets, id: \.self) { eq in
                        EQRowView(
                            name: eq,
                            isSelected: playerState.currentEQ == eq
                        ) {
                            Task {
                                await playerState.loadEQPreset(eq)
                                showEQ = false
                            }
                        }
                    }
                }
            }
            .frame(height: showEQ ? 180 : 0)
            .clipped()
            .opacity(showEQ ? 1 : 0)

            // Expandable Info section (scrollable)
            ScrollView {
                infoContent(playerState: playerState)
            }
            .background(Color.black.opacity(0.8))
            .frame(height: showInfo ? 280 : 0)
            .clipped()
            .opacity(showInfo ? 1 : 0)
            .onChange(of: playerState.title) { _, _ in
                // Refetch liner notes if info panel is open and track changed
                if showInfo {
                    Task { await playerState.fetchLinerNotes() }
                }
            }
        }
    }

    // MARK: - Info Content

    private func infoContent(playerState: PlayerState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if playerState.isLoadingLinerNotes {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let error = playerState.linerNotesError {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.4))
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                // Album art and title header
                HStack(spacing: 10) {
                    // Small album art
                    Group {
                        if let nsImage = playerState.albumArtImage {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(4)
                    .clipped()

                    VStack(alignment: .leading, spacing: 1) {
                        Text(playerState.title.isEmpty ? "Unknown" : playerState.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(playerState.artist.isEmpty ? "Unknown Artist" : playerState.artist)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer()
                }

                // Artist bio from Last.fm
                if let artistInfo = playerState.artistInfo, let bio = artistInfo.bioSummary, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About the Artist")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))
                        Text(bio)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Album description from Last.fm
                if let albumInfo = playerState.albumInfo, let wiki = albumInfo.wikiSummary, !wiki.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About the Album")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))
                        Text(wiki)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Release details from Discogs
                if let release = playerState.linerNotes {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Release Details")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))

                        if release.year != nil || release.released != nil {
                            infoDetailRow(label: "Year", value: release.displayYear)
                        }
                        infoDetailRow(label: "Label", value: release.displayLabel)
                        if !release.displayGenres.isEmpty {
                            infoDetailRow(label: "Genre", value: release.displayGenres)
                        }
                    }
                }

                // Attribution
                HStack {
                    Spacer()
                    Text("Data from Last.fm & Discogs")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }

    private func infoDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    // MARK: - Playback Controls

    private func playbackControls(playerState: PlayerState) -> some View {
        HStack(spacing: 32) {
            // Previous
            Button(action: {
                Task { await playerState.previousTrack() }
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .disabled(!playerState.isConnected)

            // Play/Pause
            Button(action: {
                Task { await playerState.togglePlayPause() }
            }) {
                Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!playerState.isConnected)

            // Next
            Button(action: {
                Task { await playerState.nextTrack() }
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .disabled(!playerState.isConnected)
        }
    }

    // MARK: - Volume Control

    private func volumeControl(playerState: PlayerState) -> some View {
        HStack(spacing: 10) {
            // Mute/unmute button
            Button(action: {
                Task { await playerState.toggleMute() }
            }) {
                Image(systemName: playerState.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundColor(playerState.isMuted ? .red.opacity(0.8) : .white.opacity(0.6))
                    .frame(width: 14)
            }
            .buttonStyle(.plain)
            .help(playerState.isMuted ? "Unmute" : "Mute")

            if !playerState.isMuted {
                Slider(
                    value: $volSlider,
                    in: 0 ... 100,
                    step: 1,
                    onEditingChanged: { editing in
                        isDraggingVolume = editing
                        if !editing {
                            Task { await playerState.setVolume(Int(volSlider)) }
                        }
                    }
                )
                .controlSize(.mini)
                .tint(.white)
                .onAppear {
                    volSlider = Double(playerState.volume)
                }
                .onChange(of: playerState.volume) { _, newValue in
                    if !isDraggingVolume {
                        volSlider = Double(newValue)
                    }
                }

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 14)
            }
        }
    }

    // MARK: - Seek Bar

    private func seekBar(playerState: PlayerState) -> some View {
        VStack(spacing: 2) {
            // Time labels above the bar
            HStack {
                Text(formatTime(Int(seekSlider)))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()

                Spacer()

                Text("-" + formatTime(playerState.duration - Int(seekSlider)))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                    .monospacedDigit()
            }

            // Custom progress bar style
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(seekSlider / Double(max(1, playerState.duration)))), height: 4)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingSeek = true
                            let percent = max(0, min(1, value.location.x / geometry.size.width))
                            seekSlider = Double(playerState.duration) * percent
                        }
                        .onEnded { _ in
                            isDraggingSeek = false
                            Task { await playerState.seek(to: Int(seekSlider)) }
                        }
                )
            }
            .frame(height: 4)
            .onAppear {
                seekSlider = Double(playerState.currentPosition)
                startSeekTimer(playerState: playerState)
            }
            .onDisappear {
                seekTimer?.invalidate()
                seekTimer = nil
            }
            .onChange(of: playerState.currentPosition) { _, newValue in
                if !isDraggingSeek {
                    seekSlider = Double(newValue)
                }
            }
            .onChange(of: playerState.isPlaying) { _, _ in
                startSeekTimer(playerState: playerState)
            }
        }
    }

    private func startSeekTimer(playerState: PlayerState) {
        seekTimer?.invalidate()
        guard playerState.isPlaying else {
            seekTimer = nil
            return
        }
        seekTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isDraggingSeek, seekSlider < Double(playerState.duration) {
                seekSlider += 1
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Header
            VStack(spacing: 6) {
                Image(systemName: "hifispeaker.2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)

                Text("WiiM Control")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(discovery.devices.isEmpty ? "Searching..." : "\(discovery.devices.count) device\(discovery.devices.count == 1 ? "" : "s") found")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 20)

            // Devices section header
            HStack {
                Text("Devices")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer()

                if discovery.isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button(action: { discovery.startDiscovery() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Device list
            if discovery.devices.isEmpty, !discovery.isSearching {
                VStack(spacing: 12) {
                    Text("No devices found")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Button("Scan for Devices") {
                        discovery.startDiscovery()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if discovery.devices.count > 4 {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(discovery.devices) { device in
                            DeviceRow(device: device) {
                                onDeviceSelected(device)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            } else {
                VStack(spacing: 4) {
                    ForEach(discovery.devices) { device in
                        DeviceRow(device: device) {
                            onDeviceSelected(device)
                        }
                    }
                }
            }

            Spacer(minLength: 16)
        }
        .background(Color.black)
        .onAppear {
            if discovery.devices.isEmpty, !discovery.isSearching {
                discovery.startDiscovery()
            }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: WiiMDevice
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Speaker icon in rounded rect
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text(device.host)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovering ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preset Row View

struct PresetRowView: View {
    let preset: WiiMPreset
    let action: () -> Void

    @State private var artworkImage: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            // Artwork
            Group {
                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "radio")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: 32, height: 32)
            .cornerRadius(4)
            .clipped()

            Text(preset.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8))
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .task {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        guard let url = preset.artworkURL else { return }

        // Try HTTPS version of the URL first
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
            if let image = NSImage(data: data) {
                await MainActor.run {
                    artworkImage = image
                }
            }
        } catch {
            // HTTPS failed, try original HTTP URL with a custom session
            // that allows local networking (for local WiiM device)
            do {
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config)
                let (data, _) = try await session.data(from: url)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        artworkImage = image
                    }
                }
            } catch {
                // Artwork won't load
            }
        }
    }
}

// MARK: - EQ Row View

struct EQRowView: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 24)

            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.gray.opacity(0.55) : Color.black.opacity(0.8))
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Liner Notes View

struct LinerNotesView: View {
    let playerState: PlayerState
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with album art
            VStack(spacing: 0) {
                // Back button row
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Album Info")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Spacer()

                    // Spacer for symmetry
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // Album art and title
                HStack(spacing: 12) {
                    // Small album art
                    Group {
                        if let nsImage = playerState.albumArtImage {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
                    .clipped()

                    // Album/track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerState.title.isEmpty ? "Unknown" : playerState.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text(playerState.artist.isEmpty ? "Unknown Artist" : playerState.artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                        if !playerState.album.isEmpty {
                            Text(playerState.album)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(Color.black)

            Divider()
                .background(Color.white.opacity(0.2))

            // Content
            if playerState.isLoadingLinerNotes {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)
                Spacer()
            } else if let error = playerState.linerNotesError {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.4))
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // LAST.FM DATA FIRST

                        // Artist bio from Last.fm
                        if let artistInfo = playerState.artistInfo, let bio = artistInfo.bioSummary, !bio.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("About the Artist")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.5))

                                Text(bio)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(10)
                            }
                        }

                        // Album description from Last.fm
                        if let albumInfo = playerState.albumInfo, let wiki = albumInfo.wikiSummary, !wiki.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("About the Album")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.5))

                                Text(wiki)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(10)
                            }
                        }

                        // DISCOGS DATA SECOND

                        // Album details from Discogs
                        if let release = playerState.linerNotes {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Release Details")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.5))

                                if release.year != nil || release.released != nil {
                                    detailRow(label: "Year", value: release.displayYear)
                                }
                                detailRow(label: "Label", value: release.displayLabel)
                                if !release.displayGenres.isEmpty {
                                    detailRow(label: "Genre", value: release.displayGenres)
                                }
                                if let country = release.country, !country.isEmpty {
                                    detailRow(label: "Country", value: country)
                                }
                            }
                        }

                        // Personnel from Discogs
                        if let release = playerState.linerNotes, !release.personnel.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Personnel")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.5))

                                ForEach(release.personnel.prefix(8), id: \.self) { person in
                                    Text(person)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                if release.personnel.count > 8 {
                                    Text("+ \(release.personnel.count - 8) more...")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                        .italic()
                                }
                            }
                        }

                        // Tracklist from Discogs
                        if let release = playerState.linerNotes, let tracks = release.tracklist, !tracks.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tracklist")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.5))

                                ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                                    HStack {
                                        Text(track.displayPosition)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.5))
                                            .frame(width: 24, alignment: .leading)
                                        Text(track.title)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                            .lineLimit(1)
                                        Spacer()
                                        if !track.displayDuration.isEmpty {
                                            Text(track.displayDuration)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                }
                            }
                        }

                        // Notes from Discogs
                        if let release = playerState.linerNotes, let notes = release.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.5))

                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(10)
                            }
                        }

                        // Attribution
                        HStack {
                            Spacer()
                            Text("Data from Last.fm & Discogs")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.3))
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.black)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
}
