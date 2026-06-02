import WidgetKit
import Foundation

struct HabitSummary: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isVerifiedToday: Bool
    let currentStreak: Int
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let habits: [HabitSummary]
    let bestStreak: Int
    let verifiedCount: Int
    let totalCount: Int
}

extension WidgetEntry {
    static let placeholder = WidgetEntry(
        date: .now,
        habits: [
            HabitSummary(id: "1", name: "Walk 10k steps", emoji: "🏃", isVerifiedToday: true, currentStreak: 7),
            HabitSummary(id: "2", name: "Read 20 min", emoji: "📚", isVerifiedToday: false, currentStreak: 3),
            HabitSummary(id: "3", name: "Drink water", emoji: "💧", isVerifiedToday: false, currentStreak: 14),
        ],
        bestStreak: 14,
        verifiedCount: 1,
        totalCount: 3
    )
}
