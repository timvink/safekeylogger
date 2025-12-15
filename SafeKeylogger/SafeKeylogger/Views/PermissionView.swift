import SwiftUI
import Cocoa

struct PermissionView: View {
    @ObservedObject var keyMonitor = KeyMonitor.shared
    @State private var isChecking = false
    @State private var showRestartHint = false
    var onPermissionGranted: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            // Title
            Text("Accessibility Permission Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Description
            Text("SafeKeylogger needs Accessibility permission to monitor keystrokes and collect typing statistics.\n\nYour data stays private and is stored locally on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Steps
            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, text: "Click \"Open System Settings\" below")
                stepRow(number: 2, text: "Find SafeKeylogger in the list")
                stepRow(number: 3, text: "Toggle the switch to enable access")
                stepRow(number: 4, text: "Come back and click \"Check Permission\"")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            // Restart hint
            if showRestartHint {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Permission enabled but not detected. Try restarting the app.")
                        .font(.callout)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: openSystemSettings) {
                    Label("Open System Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: checkPermission) {
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Check Permission", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isChecking)
                
                if showRestartHint {
                    Button(action: restartApp) {
                        Label("Restart App", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                }
            }
            
            // Quit button
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.link)
            .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 420)
        .onAppear {
            // Check immediately in case permission was granted before
            checkPermission()
        }
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.callout)
        }
    }
    
    private func openSystemSettings() {
        // Request permission (this will prompt and open settings)
        keyMonitor.requestAccessibilityPermission()
    }
    
    private func checkPermission() {
        isChecking = true
        
        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Use direct API call to check permission fresh
            let trusted = AXIsProcessTrusted()
            keyMonitor.hasAccessibilityPermission = trusted
            isChecking = false
            
            if trusted {
                onPermissionGranted()
            } else {
                // Show restart hint after first failed check
                showRestartHint = true
            }
        }
    }
    
    private func restartApp() {
        // Get the path to the current app
        let appPath = Bundle.main.bundlePath
        
        // Launch a new instance
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [appPath]
        
        do {
            try task.run()
            // Quit current instance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            // If restart fails, just quit
            NSApplication.shared.terminate(nil)
        }
    }
}

// Window controller for the permission window
class PermissionWindowController: NSWindowController {
    convenience init(onPermissionGranted: @escaping () -> Void) {
        let permissionView = PermissionView(onPermissionGranted: onPermissionGranted)
        let hostingController = NSHostingController(rootView: permissionView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SafeKeylogger Setup"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
    }
}
