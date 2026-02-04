import SwiftUI

struct MenuBarView: View {
    @Bindable var service: WiiMService
    var playerState: PlayerState?
    @Bindable var discovery: DeviceDiscovery
    @Binding var isConnected: Bool
    var onDeviceSelected: (WiiMDevice) -> Void
    var onDisconnect: () -> Void

    @State private var isMiniMode: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if isConnected, let playerState {
                connectedView(playerState: playerState)
            } else {
                SetupView(discovery: discovery, onDeviceSelected: onDeviceSelected)
            }
        }
        .frame(width: 260)
    }

    @ViewBuilder
    private func connectedView(playerState: PlayerState) -> some View {
        if isMiniMode {
            MiniModeView(playerState: playerState, isMiniMode: $isMiniMode)
        } else {
            FullModeView(
                playerState: playerState,
                service: service,
                discovery: discovery,
                isMiniMode: $isMiniMode,
                onDeviceSelected: onDeviceSelected
            )
        }
    }
}
