import SwiftUI

struct BottomTabsSection: View {
    let playerState: PlayerState

    @State private var showPresets: Bool = false
    @State private var showEQ: Bool = false
    @State private var showInfo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab headers
            HStack(spacing: 0) {
                // Presets tab
                VStack(spacing: 3) {
                    Text("Presets")
                        .font(.caption)
                        .foregroundColor(showPresets ? .white : .white.opacity(0.7))
                    Image(systemName: showPresets ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(showPresets ? .white.opacity(0.6) : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(showPresets ? Color.white.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if showPresets {
                        showPresets = false
                    } else {
                        showPresets = true
                        showEQ = false
                        showInfo = false
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 30)

                // EQ tab
                VStack(spacing: 3) {
                    Text("EQ")
                        .font(.caption)
                        .foregroundColor(showEQ ? .white : .white.opacity(0.7))
                    Image(systemName: showEQ ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(showEQ ? .white.opacity(0.6) : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(showEQ ? Color.white.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if showEQ {
                        showEQ = false
                    } else {
                        showEQ = true
                        showPresets = false
                        showInfo = false
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 30)

                // Info tab
                VStack(spacing: 3) {
                    Text("Info")
                        .font(.caption)
                        .foregroundColor(showInfo ? .white : .white.opacity(0.7))
                    Image(systemName: showInfo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(showInfo ? .white.opacity(0.6) : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(showInfo ? Color.white.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if showInfo {
                        showInfo = false
                    } else {
                        showInfo = true
                        showPresets = false
                        showEQ = false
                        Task { await playerState.fetchLinerNotes() }
                    }
                }
            }
            .background(Color.black.opacity(0.6))

            // Expandable presets list
            if !playerState.presets.isEmpty {
                VStack(spacing: 2) {
                    ForEach(playerState.presets) { preset in
                        PresetRowView(preset: preset) {
                            Task {
                                await playerState.playPreset(preset)
                                showPresets = false
                            }
                        }
                    }
                }
                .frame(height: showPresets ? nil : 0, alignment: .top)
                .clipped()
                .opacity(showPresets ? 1 : 0)
            }

            // Expandable EQ list (scrollable)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(playerState.eqPresets, id: \.self) { eq in
                        EQRowView(
                            name: eq,
                            isSelected: playerState.currentEQ == eq
                        ) {
                            Task {
                                await playerState.loadEQPreset(eq)
                                showEQ = false
                            }
                        }
                    }
                }
            }
            .frame(height: showEQ ? 180 : 0)
            .clipped()
            .opacity(showEQ ? 1 : 0)

            // Expandable Info section (scrollable)
            ScrollView {
                InfoPanelView(playerState: playerState)
            }
            .background(Color.black.opacity(0.8))
            .frame(height: showInfo ? 280 : 0)
            .clipped()
            .opacity(showInfo ? 1 : 0)
            .onChange(of: playerState.title) { _, _ in
                // Refetch liner notes if info panel is open and track changed
                if showInfo {
                    Task { await playerState.fetchLinerNotes() }
                }
            }
        }
    }
}
