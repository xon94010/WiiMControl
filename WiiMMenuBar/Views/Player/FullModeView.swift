import SwiftUI

struct FullModeView: View {
    let playerState: PlayerState
    let service: WiiMService
    @Binding var isMiniMode: Bool
    var onDisconnect: () -> Void

    var body: some View {
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
                PlaybackControls(playerState: playerState)
                VolumeControl(playerState: playerState)
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

            // Bottom tabs section (Presets & EQ)
            BottomTabsSection(playerState: playerState)
        }
    }
}
