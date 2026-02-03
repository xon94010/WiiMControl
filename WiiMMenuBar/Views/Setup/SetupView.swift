import SwiftUI

struct SetupView: View {
    @Bindable var discovery: DeviceDiscovery
    var onDeviceSelected: (WiiMDevice) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Header
            VStack(spacing: 6) {
                Image(systemName: "hifispeaker.2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)

                Text("WiiM Control")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(discovery.devices.isEmpty ? "Searching..." : "\(discovery.devices.count) device\(discovery.devices.count == 1 ? "" : "s") found")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 20)

            // Devices section header
            HStack {
                Text("Devices")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer()

                if discovery.isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button(action: { discovery.startDiscovery() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Device list
            if discovery.devices.isEmpty, !discovery.isSearching {
                VStack(spacing: 12) {
                    Text("No devices found")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Button("Scan for Devices") {
                        discovery.startDiscovery()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if discovery.devices.count > 4 {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(discovery.devices) { device in
                            DeviceRow(device: device) {
                                onDeviceSelected(device)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            } else {
                VStack(spacing: 4) {
                    ForEach(discovery.devices) { device in
                        DeviceRow(device: device) {
                            onDeviceSelected(device)
                        }
                    }
                }
            }

            Spacer(minLength: 16)
        }
        .background(Color.black)
        .onAppear {
            if discovery.devices.isEmpty, !discovery.isSearching {
                discovery.startDiscovery()
            }
        }
    }
}
