import Foundation

struct WatchHabitSummary: Codable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isVerifiedToday: Bool
    let currentStreak: Int
}

struct WatchPayload: Codable {
    let habits: [WatchHabitSummary]
    let syncedAt: Date

    var verifiedCount: Int { habits.filter(\.isVerifiedToday).count }
    var totalCount: Int { habits.count }
}
