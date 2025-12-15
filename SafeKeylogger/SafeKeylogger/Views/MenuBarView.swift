import SwiftUI

struct MenuBarView: View {
    @State private var selectedTab = 0
    @ObservedObject var keyMonitor = KeyMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            // Status indicator
            HStack {
                Circle()
                    .fill(keyMonitor.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(keyMonitor.isMonitoring ? "Recording" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Stats").tag(0)
                Text("Settings").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            Group {
                if selectedTab == 0 {
                    StatsView()
                } else {
                    SettingsView()
                }
            }
            .frame(minHeight: 300)
        }
        .frame(width: 420)
    }
}
