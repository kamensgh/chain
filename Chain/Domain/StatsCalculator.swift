import Foundation

enum StatsCalculator {

    /// All unique period-start dates within the last `days` calendar days ending on `today`.
    static func periodsInWindow(
        frequency: Frequency,
        days: Int = 30,
        today: Date
    ) -> [Date] {
        let cal = Calendar.current
        var seen = Set<Date>()
        var result: [Date] = []
        for offset in 0..<days {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let period = frequency.periodStart(for: d)
            if seen.insert(period).inserted {
                result.append(period)
            }
        }
        return result
    }

    /// Fraction of periods in the window covered by a verified entry.
    /// Callers map habit.entries to [StreakEntry] before passing in.
    static func completionRate(
        entries: [StreakEntry],
        frequency: Frequency,
        days: Int = 30,
        today: Date
    ) -> Double {
        let periods = periodsInWindow(frequency: frequency, days: days, today: today)
        guard !periods.isEmpty else { return 0.0 }
        let verifiedPeriods = Set(entries.lazy.filter { $0.status == .verified }.map { $0.periodStart })
        let hits = periods.filter { verifiedPeriods.contains($0) }.count
        return Double(hits) / Double(periods.count)
    }
}
