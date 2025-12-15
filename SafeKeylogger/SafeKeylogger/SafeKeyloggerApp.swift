import SwiftUI

@main
struct SafeKeyloggerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - app runs entirely from menu bar
        Settings {
            EmptyView()
        }
    }
}
