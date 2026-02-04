import SwiftUI

struct FullModeView: View {
    let playerState: PlayerState
    let service: WiiMService
    @Bindable var discovery: DeviceDiscovery
    @Binding var isMiniMode: Bool
    var onDeviceSelected: (WiiMDevice) -> Void

    @State private var isImmersiveMode: Bool = false

    var body: some View {
        if isImmersiveMode {
            immersiveView
        } else {
            normalView
        }
    }

    // MARK: - Immersive Album Art View

    private var immersiveView: some View {
        ZStack {
            // Full album art background
            immersiveAlbumArt
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isImmersiveMode = false
                    }
                }

            // Overlay content
            VStack {
                Spacer()

                // Floating controls pill
                HStack(spacing: 24) {
                    Button(action: {
                        Task { await playerState.previousTrack() }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task { await playerState.togglePlayPause() }
                    }) {
                        Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task { await playerState.nextTrack() }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())

                Spacer()
                    .frame(height: 20)

                // Subtle track info at bottom
                VStack(spacing: 2) {
                    if !playerState.title.isEmpty {
                        Text(playerState.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    if !playerState.artist.isEmpty {
                        Text(playerState.artist)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 260, height: 260)
    }

    private var immersiveAlbumArt: some View {
        ZStack {
            Color.black

            if let nsImage = playerState.albumArtImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 260, height: 260)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .frame(width: 260, height: 260)
    }

    // MARK: - Normal View

    private var normalView: some View {
        VStack(spacing: 0) {
            // Header with source indicator and controls
            headerView

            // Controls
            VStack(spacing: 10) {
                PlaybackControls(playerState: playerState)
                // Only show volume control for WiiM
                if playerState.canControlVolume {
                    VolumeControl(playerState: playerState)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black)

            // Album art (tap to enter immersive mode)
            AlbumArtView(image: playerState.albumArtImage)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isImmersiveMode = true
                    }
                }

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
                    SeekBar(playerState: playerState)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.85))

            // Bottom tabs section (Presets & EQ only for WiiM, Info always available)
            BottomTabsSection(playerState: playerState)
        }
    }

    private var headerView: some View {
        VStack(spacing: 2) {
            // Top row with close and mini buttons
            HStack {
                // Close button
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer()

                // Mini mode button
                Button(action: { isMiniMode = true }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Mini Mode")
            }

            // Source menu centered below
            sourceMenu

            // EQ indicator (only when WiiM active and EQ selected)
            if playerState.isWiiMActive,
               !playerState.currentEQ.isEmpty,
               !playerState.eqPresets.isEmpty,
               playerState.eqPresets.contains(playerState.currentEQ)
            {
                Text("EQ: \(playerState.currentEQ)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    @State private var showSourceMenu = false

    private var sourceMenu: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(playerState.isConnected ? Color(red: 0.2, green: 0.9, blue: 0.4) : .orange)
                    .frame(width: 8, height: 8)

                // Show WiiM device name
                Text(service.deviceName.isEmpty ? "WiiM" : service.deviceName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showSourceMenu = true
        }
        .popover(isPresented: $showSourceMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // WiiM devices
                if !discovery.devices.isEmpty {
                    ForEach(discovery.devices) { device in
                        Button(action: {
                            onDeviceSelected(device)
                            showSourceMenu = false
                        }) {
                            HStack {
                                Image(systemName: "hifispeaker.fill")
                                Text(device.displayName)
                                Spacer()
                                if isCurrentWiiMDevice(device) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Searching for devices...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .frame(minWidth: 180)
        }
        .onAppear {
            if discovery.devices.isEmpty {
                discovery.startDiscovery()
            }
        }
    }

    @ViewBuilder
    private var sourceDisplayLabel: some View {
        if playerState.sourceMode == .auto {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                SourceIndicator(
                    identifier: playerState.activeSourceIdentifier,
                    appIcon: playerState.isLocalActive ? playerState.sourceAppIcon : nil,
                    compact: false
                )
            }
        } else {
            SourceIndicator(
                identifier: playerState.activeSourceIdentifier,
                appIcon: playerState.isLocalActive ? playerState.sourceAppIcon : nil,
                compact: false
            )
        }
    }

    private func isCurrentWiiMDevice(_ device: WiiMDevice) -> Bool {
        service.ipAddress == device.host
    }
}
