import SwiftUI

struct FullModeView: View {
    let playerState: PlayerState
    let service: WiiMService
    @Bindable var discovery: DeviceDiscovery
    @Binding var isMiniMode: Bool
    var onDeviceSelected: (WiiMDevice) -> Void
    var onSourceModeChanged: (SourceMode) -> Void

    var body: some View {
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

            // Album art
            AlbumArtView(image: playerState.albumArtImage)

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

                // Show source name as text
                Text(playerState.activeSourceIdentifier.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
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
                // WiiM devices section
                if !discovery.devices.isEmpty {
                    ForEach(discovery.devices) { device in
                        Button(action: {
                            selectWiiMDevice(device)
                            showSourceMenu = false
                        }) {
                            HStack {
                                Image(systemName: "hifispeaker.fill")
                                Text(device.displayName)
                                Spacer()
                                if isCurrentWiiMDevice(device) && playerState.sourceMode == .wiim {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider()
                }

                // Local Media option
                Button(action: {
                    onSourceModeChanged(.local)
                    showSourceMenu = false
                }) {
                    HStack {
                        Image(systemName: "desktopcomputer")
                        Text("Local Media")
                        Spacer()
                        if playerState.sourceMode == .local {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Divider()

                // Auto option
                Button(action: {
                    onSourceModeChanged(.auto)
                    showSourceMenu = false
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Auto")
                        Spacer()
                        if playerState.sourceMode == .auto {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
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

    private func selectWiiMDevice(_ device: WiiMDevice) {
        onDeviceSelected(device)
        onSourceModeChanged(.wiim)
    }
}
