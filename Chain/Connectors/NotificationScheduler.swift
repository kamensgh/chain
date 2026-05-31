import UserNotifications
import Foundation

enum NotificationScheduler {

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func schedule(for habit: Habit) async {
        guard let reminderTime = habit.reminderTime else {
            cancel(for: habit)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "\(habit.emoji) \(habit.name)"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: habit.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for habit: Habit) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [habit.id.uuidString])
    }

    static func rescheduleAll(_ habits: [Habit]) async {
        let identifiers = habits.map { $0.id.uuidString }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
        for habit in habits where habit.reminderTime != nil {
            await schedule(for: habit)
        }
    }

    static func scheduleMilestone(for habit: Habit, streak: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streak)-Day Streak!"
        content.body = "\(habit.emoji) \(habit.name) — you're on fire!"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "milestone-\(habit.id.uuidString)-\(streak)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
