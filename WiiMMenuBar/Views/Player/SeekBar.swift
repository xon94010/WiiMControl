import SwiftUI

struct SeekBar: View {
    let playerState: PlayerState

    @State private var seekSlider: Double = 0
    @State private var isDraggingSeek: Bool = false
    @State private var seekTimer: Timer?

    var body: some View {
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
                    // Only enable drag gesture if seeking is supported
                    playerState.canSeek ?
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
                        : nil
                )
                // Visual indication that seeking is disabled
                .opacity(playerState.canSeek ? 1.0 : 0.7)
            }
            .frame(height: 4)
            .onAppear {
                seekSlider = Double(playerState.currentPosition)
                startSeekTimer()
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
                startSeekTimer()
            }

            // Show hint when seeking is not available
            if !playerState.canSeek {
                Text("Seek not available")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    private func startSeekTimer() {
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
}
