import Foundation
import Observation
import WidgetKit

@Observable
final class WatchHabitStore {
    static let shared = WatchHabitStore()
    private init() {}

    var habits: [WatchHabitSummary] = []
    var syncedAt: Date?

    var verifiedCount: Int { habits.filter(\.isVerifiedToday).count }
    var totalCount: Int { habits.count }

    func update(from payload: WatchPayload) {
        habits = payload.habits
        syncedAt = payload.syncedAt
        UserDefaults.standard.set(verifiedCount, forKey: "watch_verifiedCount")
        UserDefaults.standard.set(totalCount, forKey: "watch_totalCount")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func markVerified(habitID: String) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let h = habits[idx]
        habits[idx] = WatchHabitSummary(
            id: h.id, name: h.name, emoji: h.emoji,
            isVerifiedToday: true, currentStreak: h.currentStreak
        )
        UserDefaults.standard.set(verifiedCount, forKey: "watch_verifiedCount")
        UserDefaults.standard.set(totalCount, forKey: "watch_totalCount")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
