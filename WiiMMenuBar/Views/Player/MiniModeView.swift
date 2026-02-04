import SwiftUI

struct MiniModeView: View {
    let playerState: PlayerState
    @Binding var isMiniMode: Bool

    @State private var volSlider: Double = 50
    @State private var isDraggingVolume: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Header with expand button and source indicator
            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer()

                // Source indicator + Track info
                HStack(spacing: 6) {
                    SourceIndicatorCompact(
                        identifier: playerState.activeSourceIdentifier,
                        appIcon: playerState.isLocalActive ? playerState.sourceAppIcon : nil
                    )

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

            // Volume (only for WiiM)
            if playerState.canControlVolume {
                HStack(spacing: 8) {
                    Button(action: { Task { await playerState.toggleMute() } }) {
                        Image(systemName: playerState.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .font(.system(size: 9))
                            .foregroundColor(playerState.isMuted ? .red.opacity(0.8) : .white.opacity(0.4))
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)

                    if !playerState.isMuted {
                        Slider(value: $volSlider, in: 0 ... 100, step: 1) { editing in
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
            } else {
                // Just add some bottom padding when no volume control
                Spacer()
                    .frame(height: 10)
            }
        }
        .background(Color.black)
    }
}
