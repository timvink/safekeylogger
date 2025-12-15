import SwiftUI

struct SettingsView: View {
    @ObservedObject var keyMonitor = KeyMonitor.shared
    @State private var databasePath: String = DatabaseManager.shared.databasePath
    @State private var showingClearConfirmation = false
    @State private var showingPathPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            Divider()

            // Monitoring toggle
            GroupBox {
                HStack {
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
                        Button("Grant Permission") {
                            keyMonitor.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }

            // Database path
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database Location")
                        .fontWeight(.medium)

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

            // Clear statistics
            GroupBox {
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
                Text("SafeKeylogger v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
            }
        }
        .padding()
        .alert("Clear All Statistics?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                DatabaseManager.shared.clearAllStatistics()
            }
        } message: {
            Text("This will permanently delete all recorded character, bigram, and trigram counts. This action cannot be undone.")
        }
        .onAppear {
            // Refresh permission status
            keyMonitor.checkAccessibilityPermission()
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
}
