import Foundation
import SwiftData

@MainActor
enum HabitVerifier {
    static func verify(_ habit: Habit, allHabits: [Habit], context: ModelContext, companions: [Companion]) {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
            guard existing.status != .verified else { return }
            existing.status = .verified
            existing.verifMethod = .manual
            existing.verifiedAt = Date()
        } else {
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = .verified
            entry.verifMethod = .manual
            entry.verifiedAt = Date()
            context.insert(entry)
        }
        applyDailyXP(allHabits: allHabits, companions: companions)
        try? context.save()
    }

    private static func applyDailyXP(allHabits: [Habit], companions: [Companion]) {
        guard let companion = companions.first else { return }
        if let last = companion.lastXPDate, Calendar.current.isDateInToday(last) { return }
        let needStates: [NeedState] = CompanionNeed.allCases.prefix(min(allHabits.count, 3)).map { need in
            let habit = allHabits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
        }
        let delta = CompanionEngine.xpDelta(needStates: needStates)
        if delta > 0 {
            companion.applyXP(delta)
            companion.lastXPDate = Date()
        }
    }
}
