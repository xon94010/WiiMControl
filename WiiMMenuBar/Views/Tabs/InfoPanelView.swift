import SwiftUI

struct InfoPanelView: View {
    let playerState: PlayerState

    var body: some View {
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
}
