import Foundation
import ServiceManagement

/// Manages the app's launch at login setting using SMAppService
enum LaunchAtLogin {
    /// Whether the app is currently set to launch at login
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Toggle launch at login on or off
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}
