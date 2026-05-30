import Foundation

struct StreakEntry {
    let periodStart: Date
    let status: EntryStatus
}

enum StreakCalculator {

    static func current(
        entries: [StreakEntry],
        frequency: Frequency,
        today: Date,
        gracePeriod: Bool = false
    ) -> Int {
        let cal = Calendar.current
        let relevant = entries.filter {
            gracePeriod ? $0.status != .pending : $0.status == .verified
        }.sorted { $0.periodStart > $1.periodStart }

        guard !relevant.isEmpty else { return 0 }

        var streak = 0
        var cursor = frequency.periodStart(for: today)

        for entry in relevant {
            let entryPeriod = frequency.periodStart(for: entry.periodStart)
            guard entryPeriod == cursor else { break }
            streak += 1
            let dayBefore = cal.date(byAdding: .day, value: -1, to: cursor)!
            cursor = frequency.periodStart(for: dayBefore)
        }

        return streak
    }

    static func longest(entries: [StreakEntry], frequency: Frequency) -> Int {
        let cal = Calendar.current
        let sorted = entries
            .filter { $0.status == .verified }
            .sorted { $0.periodStart < $1.periodStart }

        guard !sorted.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        var prevPeriod: Date?

        for entry in sorted {
            let period = frequency.periodStart(for: entry.periodStart)
            if let prev = prevPeriod {
                let dayBefore = cal.date(byAdding: .day, value: -1, to: period)!
                let expectedPrev = frequency.periodStart(for: dayBefore)
                current = (expectedPrev == prev) ? current + 1 : 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prevPeriod = period
        }

        return longest
    }
}
