import UserNotifications
import Foundation

enum SmartNotificationScheduler {

    static let nudgeID  = "smart-nudge-today"
    static let atRiskID = "smart-at-risk-today"
    static let weeklyID = "smart-weekly-summary"

    static func rescheduleForToday(habits: [Habit]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional ||
              settings.authorizationStatus == .ephemeral else { return }
        guard !habits.isEmpty else { return }

        let allVerified = habits.allSatisfy { habit in
            let periodStart = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.first { $0.periodStart == periodStart }?.status == .verified
        }

        if allVerified {
            // Weekly summary is intentionally not cancelled here — it's a recap, not a nudge
            center.removePendingNotificationRequests(withIdentifiers: [nudgeID, atRiskID])
        } else {
            if UserDefaults.standard.bool(forKey: "nudgeEnabled") {
                await scheduleDaily(
                    id: nudgeID,
                    title: "Don't forget your habits today! 🔥",
                    body: "Keep your streak alive — check in before midnight.",
                    hour: UserDefaults.standard.integer(forKey: "nudgeHour"),
                    minute: UserDefaults.standard.integer(forKey: "nudgeMinute")
                )
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [nudgeID])
            }

            if UserDefaults.standard.bool(forKey: "atRiskEnabled") {
                await scheduleDaily(
                    id: atRiskID,
                    title: "Some streaks are at risk — check in before midnight! ⚠️",
                    body: "Don't break the chain.",
                    hour: UserDefaults.standard.integer(forKey: "atRiskHour"),
                    minute: UserDefaults.standard.integer(forKey: "atRiskMinute")
                )
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [atRiskID])
            }
        }

        if UserDefaults.standard.bool(forKey: "weeklyEnabled") {
            await scheduleWeekly(
                id: weeklyID,
                title: "How did your habits go this week? 📊",
                body: "Tap to review your progress.",
                hour: UserDefaults.standard.integer(forKey: "weeklyHour"),
                minute: UserDefaults.standard.integer(forKey: "weeklyMinute")
            )
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [weeklyID])
        }
    }

    private static func scheduleDaily(id: String, title: String, body: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func scheduleWeekly(id: String, title: String, body: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
