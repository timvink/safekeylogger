import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var permissionWindowController: PermissionWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always setup menu bar first so icon is visible
        setupMenuBar()
        
        // Check permission first
        KeyMonitor.shared.checkAccessibilityPermission()
        
        if KeyMonitor.shared.hasAccessibilityPermission {
            // Permission granted, start monitoring and show settings
            KeyMonitor.shared.startMonitoring()
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
    
    // MARK: - Permission Window
    
    private func showPermissionWindow() {
        permissionWindowController = PermissionWindowController { [weak self] in
            // Permission granted callback
            self?.permissionWindowController?.close()
            self?.permissionWindowController = nil
            KeyMonitor.shared.startMonitoring()
            self?.updateMenuBarMenu()
            self?.openSettings()
        }
        permissionWindowController?.showWindow(nil)
        permissionWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        // Create status item with fixed length for text
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use a simple text title that's always visible
            button.title = "⌨️"
            // Alternative: use attributed string for better styling
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14)
            ]
            button.attributedTitle = NSAttributedString(string: "⌨️", attributes: attributes)
        }
        
        updateMenuBarMenu()
    }
    
    private func updateMenuBarMenu() {
        guard statusItem != nil else { return }
        
        let menu = NSMenu()
        
        // Status item
        let statusText: String
        let statusImage: String
        
        if !KeyMonitor.shared.hasAccessibilityPermission {
            statusText = "Status: No Permission"
            statusImage = "exclamationmark.triangle"
        } else if KeyMonitor.shared.isMonitoring {
            statusText = "Status: Active"
            statusImage = "checkmark.circle.fill"
        } else {
            statusText = "Status: Paused"
            statusImage = "pause.circle"
        }
        
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.image = NSImage(systemSymbolName: statusImage, accessibilityDescription: nil)
        if KeyMonitor.shared.hasAccessibilityPermission && KeyMonitor.shared.isMonitoring {
            statusItem.image?.isTemplate = true
        }
        menu.addItem(statusItem)
        
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
        
        self.statusItem?.menu = menu
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
