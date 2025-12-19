import Foundation
import Combine
import ServiceManagement

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let confirmQuit = "confirmQuit"
        static let autoStartMonitoring = "autoStartMonitoring"
        static let launchAtLogin = "launchAtLogin"
    }

    // Published properties for SwiftUI bindings
    @Published var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
        }
    }

    @Published var confirmQuit: Bool {
        didSet {
            defaults.set(confirmQuit, forKey: Keys.confirmQuit)
        }
    }

    @Published var autoStartMonitoring: Bool {
        didSet {
            defaults.set(autoStartMonitoring, forKey: Keys.autoStartMonitoring)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    private init() {
        // Register defaults (first launch values)
        defaults.register(defaults: [
            Keys.showMenuBarIcon: true,
            Keys.confirmQuit: true,
            Keys.autoStartMonitoring: true,
            Keys.launchAtLogin: true  // Enabled by default
        ])

        // Load saved values
        self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        self.confirmQuit = defaults.bool(forKey: Keys.confirmQuit)
        self.autoStartMonitoring = defaults.bool(forKey: Keys.autoStartMonitoring)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Sync launch at login state on startup
        updateLaunchAtLogin(enabled: launchAtLogin)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        } else {
            // Fallback for macOS 12 and earlier
            SMLoginItemSetEnabled("com.safekeylogger.app" as CFString, enabled)
        }
    }
}
