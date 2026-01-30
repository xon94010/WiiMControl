import SwiftUI

@main
struct WiiMMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private var service = WiiMService()
    private var playerState: PlayerState?
    private var discovery = DeviceDiscovery()
    private var isConnected = false

    func applicationDidFinishLaunching(_: Notification) {
        // Create status bar item with square length for proper popover centering
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hifispeaker.fill", accessibilityDescription: "WiiM")
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover)
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 500)
        popover.behavior = .transient
        popover.animates = true

        updatePopoverContent()

        // Auto-connect if we have a saved device
        if service.isConfigured {
            let state = PlayerState(service: service)
            playerState = state
            state.startPolling()
            isConnected = true
            updatePopoverContent()
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Use a zero-size rect at the center for precise arrow positioning
                let buttonBounds = button.bounds
                let centerPoint = NSRect(
                    x: buttonBounds.midX,
                    y: buttonBounds.midY,
                    width: 0,
                    height: 0
                )
                popover.show(relativeTo: centerPoint, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func updatePopoverContent() {
        let contentView = MenuBarView(
            service: service,
            playerState: playerState,
            discovery: discovery,
            isConnected: Binding(
                get: { self.isConnected },
                set: { self.isConnected = $0 }
            ),
            onDeviceSelected: { [weak self] device in
                self?.selectDevice(device)
            },
            onDisconnect: { [weak self] in
                self?.disconnect()
            }
        )

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func selectDevice(_ device: WiiMDevice) {
        playerState?.stopPolling()
        service.ipAddress = device.host
        service.deviceName = device.displayName
        let state = PlayerState(service: service)
        playerState = state
        state.startPolling()
        isConnected = true
        updatePopoverContent()
    }

    private func disconnect() {
        playerState?.stopPolling()
        playerState = nil
        service.ipAddress = ""
        service.deviceName = ""
        isConnected = false
        discovery.startDiscovery()
        updatePopoverContent()
    }
}
