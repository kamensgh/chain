import WidgetKit
import SwiftData
import Foundation

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = buildEntry()
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func buildEntry() -> WidgetEntry {
        guard let container = try? ModelContainerFactory.make(inAppGroup: true) else {
            return .placeholder
        }
        let ctx = ModelContext(container)
        let habits = (try? ctx.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let today = Date()
        var bestStreak = 0
        let summaries: [HabitSummary] = habits.map { habit in
            let streakEntries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            let isVerified = !HabitScheduler.isDue(frequency: habit.frequency, entries: streakEntries, on: today)
            let streak = StreakCalculator.current(entries: streakEntries, frequency: habit.frequency, today: today)
            if streak > bestStreak { bestStreak = streak }
            return HabitSummary(
                id: habit.id.uuidString,
                name: habit.name,
                emoji: habit.emoji,
                isVerifiedToday: isVerified,
                currentStreak: streak
            )
        }
        return WidgetEntry(
            date: today,
            habits: summaries,
            bestStreak: bestStreak,
            verifiedCount: summaries.filter(\.isVerifiedToday).count,
            totalCount: summaries.count
        )
    }
}
