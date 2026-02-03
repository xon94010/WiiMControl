import SwiftUI

struct VolumeControl: View {
    let playerState: PlayerState

    @State private var volSlider: Double = 50
    @State private var isDraggingVolume: Bool = false

    var body: some View {
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
}
