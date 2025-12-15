import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let confirmQuit = "confirmQuit"
        static let autoStartMonitoring = "autoStartMonitoring"
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
    
    private init() {
        // Register defaults (first launch values)
        defaults.register(defaults: [
            Keys.showMenuBarIcon: true,
            Keys.confirmQuit: true,
            Keys.autoStartMonitoring: true
        ])
        
        // Load saved values
        self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        self.confirmQuit = defaults.bool(forKey: Keys.confirmQuit)
        self.autoStartMonitoring = defaults.bool(forKey: Keys.autoStartMonitoring)
    }
}
