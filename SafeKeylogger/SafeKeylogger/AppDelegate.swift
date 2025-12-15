import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var permissionWindowController: PermissionWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar if enabled
        if SettingsManager.shared.showMenuBarIcon {
            setupMenuBar()
        }
        
        // Listen for menu bar visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarVisibilityChange),
            name: .menuBarIconVisibilityChanged,
            object: nil
        )
        
        // Check permission first
        KeyMonitor.shared.checkAccessibilityPermission()
        
        if KeyMonitor.shared.hasAccessibilityPermission {
            // Permission granted, start monitoring if enabled and show settings
            if SettingsManager.shared.autoStartMonitoring {
                KeyMonitor.shared.startMonitoring()
            }
            openSettings()
        } else {
            // Show permission window
            showPermissionWindow()
        }
        
        // Observe permission changes to update menu
        KeyMonitor.shared.$hasAccessibilityPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarMenu()
            }
            .store(in: &cancellables)
        
        KeyMonitor.shared.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarMenu()
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyMonitor.shared.stopMonitoring()
    }
    
    // Handle quit confirmation
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if SettingsManager.shared.confirmQuit {
            let alert = NSAlert()
            alert.messageText = "Quit SafeKeylogger?"
            alert.informativeText = "Keystroke monitoring will stop until you reopen the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                return .terminateNow
            } else {
                return .terminateCancel
            }
        }
        return .terminateNow
    }
    
    // Handle app re-open (e.g., clicking icon in Dock or Spotlight while running)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }
    
    @objc private func handleMenuBarVisibilityChange() {
        if SettingsManager.shared.showMenuBarIcon {
            if statusItem == nil {
                setupMenuBar()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    // MARK: - Permission Window
    
    private func showPermissionWindow() {
        permissionWindowController = PermissionWindowController { [weak self] in
            // Permission granted callback
            self?.permissionWindowController?.close()
            self?.permissionWindowController = nil
            if SettingsManager.shared.autoStartMonitoring {
                KeyMonitor.shared.startMonitoring()
            }
            self?.updateMenuBarMenu()
            self?.openSettings()
        }
        permissionWindowController?.showWindow(nil)
        permissionWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol as template image (adapts to light/dark mode)
            if let image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "SafeKeylogger") {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                if let configuredImage = image.withSymbolConfiguration(config) {
                    configuredImage.isTemplate = true  // Makes it adapt to menu bar appearance
                    button.image = configuredImage
                }
            }
        }
        
        updateMenuBarMenu()
    }
    
    private func updateMenuBarMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        // Status item with colored dot indicator
        let statusText: String
        let dotColor: NSColor
        
        if !KeyMonitor.shared.hasAccessibilityPermission {
            statusText = "No Permission"
            dotColor = .systemOrange
        } else if KeyMonitor.shared.isMonitoring {
            statusText = "Recording"
            dotColor = .systemGreen
        } else {
            statusText = "Paused"
            dotColor = .systemGray
        }
        
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.image = createStatusDotImage(color: dotColor)
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle monitoring (only if permission granted)
        if KeyMonitor.shared.hasAccessibilityPermission {
            let toggleTitle = KeyMonitor.shared.isMonitoring ? "Pause Monitoring" : "Resume Monitoring"
            let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring), keyEquivalent: "")
            toggleItem.target = self
            menu.addItem(toggleItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Open database folder
        let openFolderItem = NSMenuItem(title: "Open Database Folder", action: #selector(openDatabaseFolder), keyEquivalent: "o")
        openFolderItem.target = self
        menu.addItem(openFolderItem)
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit SafeKeylogger", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func createStatusDotImage(color: NSColor) -> NSImage {
        let size: CGFloat = 10
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            color.setFill()
            let dot = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            dot.fill()
            return true
        }
        return image
    }
    
    // MARK: - Menu Actions
    
    @objc private func toggleMonitoring() {
        if KeyMonitor.shared.isMonitoring {
            KeyMonitor.shared.stopMonitoring()
        } else {
            KeyMonitor.shared.startMonitoring()
        }
    }
    
    @objc private func openDatabaseFolder() {
        let path = DatabaseManager.shared.databasePath
        let folderPath = (path as NSString).deletingLastPathComponent
        let folderURL = URL(fileURLWithPath: folderPath)
        
        // Create folder if it doesn't exist
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: folderPath)
    }
    
    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
