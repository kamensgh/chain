import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Notifications") {
                Text("Reminder settings coming soon")
                    .foregroundStyle(.secondary)
            }
            Section("Connectors") {
                Text("App connections coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
