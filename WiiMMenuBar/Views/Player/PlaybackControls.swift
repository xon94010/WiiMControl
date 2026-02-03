import SwiftUI

struct PlaybackControls: View {
    let playerState: PlayerState

    var body: some View {
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
}
