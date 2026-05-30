import Foundation

enum HabitScheduler {

    static func periodStart(for frequency: Frequency, on date: Date) -> Date {
        frequency.periodStart(for: date)
    }

    static func isDue(frequency: Frequency, entries: [StreakEntry], on date: Date) -> Bool {
        let period = periodStart(for: frequency, on: date)
        return !entries.contains { $0.periodStart == period && $0.status == .verified }
    }

    static func entry(for frequency: Frequency, entries: [StreakEntry], on date: Date) -> StreakEntry? {
        let period = periodStart(for: frequency, on: date)
        return entries.first { $0.periodStart == period }
    }
}
