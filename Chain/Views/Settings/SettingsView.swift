import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
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
            Group {
                NotificationRowView(
                    label: "End-of-day nudge",
                    enabledKey: "nudgeEnabled", enabledDefault: true,
                    hourKey: "nudgeHour", hourDefault: 21,
                    minuteKey: "nudgeMinute", minuteDefault: 0,
                    habits: habits
                )
                NotificationRowView(
                    label: "Streak at risk",
                    enabledKey: "atRiskEnabled", enabledDefault: true,
                    hourKey: "atRiskHour", hourDefault: 22,
                    minuteKey: "atRiskMinute", minuteDefault: 0,
                    habits: habits
                )
                NotificationRowView(
                    label: "Weekly summary",
                    enabledKey: "weeklyEnabled", enabledDefault: true,
                    hourKey: "weeklyHour", hourDefault: 20,
                    minuteKey: "weeklyMinute", minuteDefault: 0,
                    habits: habits
                )
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

private struct NotificationRowView: View {
    let label: String
    let enabledDefault: Bool
    let hourDefault: Int
    let minuteDefault: Int
    let habits: [Habit]

    @AppStorage private var enabled: Bool
    @AppStorage private var hour: Int
    @AppStorage private var minute: Int

    init(label: String,
         enabledKey: String, enabledDefault: Bool,
         hourKey: String, hourDefault: Int,
         minuteKey: String, minuteDefault: Int,
         habits: [Habit]) {
        self.label = label
        self.enabledDefault = enabledDefault
        self.hourDefault = hourDefault
        self.minuteDefault = minuteDefault
        self.habits = habits
        _enabled = AppStorage(wrappedValue: enabledDefault, enabledKey)
        _hour    = AppStorage(wrappedValue: hourDefault,    hourKey)
        _minute  = AppStorage(wrappedValue: minuteDefault,  minuteKey)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour   = comps.hour   ?? hourDefault
                minute = comps.minute ?? minuteDefault
            }
        )
    }

    var body: some View {
        Toggle(label, isOn: $enabled)
            .onChange(of: enabled) { _, _ in
                Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
            }
        if enabled {
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .onChange(of: timeBinding.wrappedValue) { _, _ in
                    Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
                }
        }
    }
}
