import SwiftUI

/// Displays an icon indicating the current media source
struct SourceIndicator: View {
    let identifier: MediaSourceIdentifier
    var appIcon: NSImage? = nil
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            // Show app icon if available, otherwise fall back to SF Symbol
            if let appIcon = appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: compact ? 14 : 16, height: compact ? 14 : 16)
                    .cornerRadius(compact ? 3 : 4)
            } else {
                Image(systemName: identifier.iconName)
                    .font(.system(size: compact ? 10 : 12))
                    .foregroundColor(Color(nsColor: identifier.iconColor))
            }

            if !compact {
                Text(identifier.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

/// Compact version showing just the icon with a tooltip
struct SourceIndicatorCompact: View {
    let identifier: MediaSourceIdentifier
    var appIcon: NSImage? = nil

    var body: some View {
        Group {
            if let appIcon = appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .cornerRadius(3)
            } else {
                Image(systemName: identifier.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: identifier.iconColor))
            }
        }
        .help(identifier.displayName)
    }
}

/// WiiM device icon - simple text logo
struct WiiMIcon: View {
    var body: some View {
        Text("WiiM")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }
}
