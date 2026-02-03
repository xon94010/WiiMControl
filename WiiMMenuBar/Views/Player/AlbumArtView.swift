import SwiftUI

struct AlbumArtView: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            Color.black // Black background for letterboxing

            if let nsImage = image {
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
    }
}
