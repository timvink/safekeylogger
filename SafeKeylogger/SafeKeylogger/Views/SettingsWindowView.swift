import SwiftUI
import Cocoa

// Window controller for the settings window
class SettingsWindowController: NSWindowController {
    convenience init() {
        let settingsView = SettingsWindowView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SafeKeylogger Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 500))
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
    }
}

struct SettingsWindowView: View {
    @ObservedObject var keyMonitor = KeyMonitor.shared
    @ObservedObject var settings = SettingsManager.shared
    @State private var databasePath: String = DatabaseManager.shared.databasePath
    @State private var showingClearConfirmation = false
    @State private var isPulsing = false
    
    var statusColor: Color {
        if !keyMonitor.hasAccessibilityPermission {
            return .orange
        } else if keyMonitor.isMonitoring {
            return .green
        } else {
            return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Monitoring section
            GroupBox {
                HStack(spacing: 12) {
                    // Status indicator with pulsing animation
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(isPulsing && keyMonitor.isMonitoring ? 1.3 : 1.0)
                            .opacity(isPulsing && keyMonitor.isMonitoring ? 0 : 1)
                        
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                    }
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear { isPulsing = true }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keystroke Monitoring")
                            .fontWeight(.medium)

                        if keyMonitor.hasAccessibilityPermission {
                            Text(keyMonitor.isMonitoring ? "Recording keystrokes" : "Monitoring paused")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Requires Accessibility permission")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    if keyMonitor.hasAccessibilityPermission {
                        Toggle("", isOn: Binding(
                            get: { keyMonitor.isMonitoring },
                            set: { newValue in
                                if newValue {
                                    keyMonitor.startMonitoring()
                                } else {
                                    keyMonitor.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                    } else {
                        VStack(spacing: 8) {
                            Button("Grant Permission") {
                                keyMonitor.requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Recheck Permission") {
                                keyMonitor.checkAccessibilityPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Monitoring", systemImage: "keyboard")
            }

            // App preferences section
            GroupBox(label: Label("Preferences", systemImage: "gearshape")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show icon in menu bar", isOn: Binding(
                        get: { settings.showMenuBarIcon },
                        set: { newValue in
                            settings.showMenuBarIcon = newValue
                            NotificationCenter.default.post(name: .menuBarIconVisibilityChanged, object: nil)
                        }
                    ))

                    Toggle("Launch at login", isOn: $settings.launchAtLogin)

                    Toggle("Start monitoring automatically on launch", isOn: $settings.autoStartMonitoring)

                    Toggle("Ask for confirmation when quitting", isOn: $settings.confirmQuit)
                }
                .padding(.vertical, 4)
            }

            // Database location section
            GroupBox(label: Label("Database Location", systemImage: "folder")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Path", text: $databasePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        Button("Browse...") {
                            selectDatabasePath()
                        }
                    }

                    HStack {
                        Button("Reset to Default") {
                            databasePath = DatabaseManager.shared.defaultDatabasePath
                            DatabaseManager.shared.databasePath = databasePath
                        }
                        .buttonStyle(.link)
                        
                        Button("Open in Finder") {
                            openDatabaseFolder()
                        }
                        .buttonStyle(.link)

                        Spacer()

                        if databasePath != DatabaseManager.shared.databasePath {
                            Button("Apply") {
                                DatabaseManager.shared.databasePath = databasePath
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Data management section
            GroupBox(label: Label("Data Management", systemImage: "trash")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clear Statistics")
                            .fontWeight(.medium)
                        Text("Permanently delete all recorded data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Clear All Data", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // About section
            HStack {
                Text("SafeKeylogger v1.0.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 420)
        .alert("Clear All Statistics?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                DatabaseManager.shared.clearAllStatistics()
            }
        } message: {
            Text("This will permanently delete all recorded character, bigram, and trigram counts. This action cannot be undone.")
        }
        .onAppear {
            // Refresh permission status and path
            keyMonitor.checkAccessibilityPermission()
            databasePath = DatabaseManager.shared.databasePath
        }
    }

    private func selectDatabasePath() {
        let panel = NSSavePanel()
        panel.title = "Choose Database Location"
        panel.nameFieldLabel = "Database File:"
        panel.nameFieldStringValue = "keystrokes.db"
        panel.allowedContentTypes = [.database]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            databasePath = url.path
            DatabaseManager.shared.databasePath = databasePath
        }
    }
    
    private func openDatabaseFolder() {
        let path = DatabaseManager.shared.databasePath
        let folderPath = (path as NSString).deletingLastPathComponent
        let folderURL = URL(fileURLWithPath: folderPath)
        
        // Create folder if it doesn't exist
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: folderPath)
    }
}

// Notification for menu bar icon visibility changes
extension Notification.Name {
    static let menuBarIconVisibilityChanged = Notification.Name("menuBarIconVisibilityChanged")
}
