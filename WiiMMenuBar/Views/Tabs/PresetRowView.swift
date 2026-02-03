import SwiftUI

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
