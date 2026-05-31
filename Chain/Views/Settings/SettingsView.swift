import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section("Companion") {
                CompanionSettingsView()
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Notifications") {
                notificationStatusView
            }

            Section("Connectors") {
                Text("App connections coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task {
            authStatus = await UNUserNotificationCenter.current()
                .notificationSettings().authorizationStatus
        }
    }

    @ViewBuilder
    private var notificationStatusView: some View {
        switch authStatus {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow notifications to receive habit reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Allow Notifications") {
                    Task {
                        await NotificationScheduler.requestAuthorization()
                        authStatus = await UNUserNotificationCenter.current()
                            .notificationSettings().authorizationStatus
                    }
                }
            }
        case .authorized, .provisional, .ephemeral:
            VStack(alignment: .leading, spacing: 4) {
                Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Reminders are set per-habit in the Habits tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications are blocked.")
                    .foregroundStyle(.secondary)
                #if os(iOS)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif
            }
        @unknown default:
            EmptyView()
        }
    }
}
