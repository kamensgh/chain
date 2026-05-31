import Testing
import Foundation
@testable import ChainDomain

struct StatsCalculatorTests {

    // Fixed anchor so tests don't break at midnight
    let anchor: Date = {
        var c = DateComponents()
        c.year = 2024; c.month = 1; c.day = 15
        return Calendar.current.date(from: c)!
    }()

    let cal = Calendar.current

    func day(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: anchor)!
    }

    func verified(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .verified)
    }

    @Test func dailyWindowReturns30() {
        let periods = StatsCalculator.periodsInWindow(frequency: .daily, days: 30, today: anchor)
        #expect(periods.count == 30)
    }

    @Test func weeklyWindowCountMatchesCalendar() {
        let cal = Calendar.current
        let expected = Set((0..<30).compactMap { offset -> Date? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: anchor) else { return nil }
            return Frequency.weekly.periodStart(for: d)
        }).count
        let periods = StatsCalculator.periodsInWindow(frequency: .weekly, days: 30, today: anchor)
        #expect(periods.count == expected)
    }

    @Test func periodsAreDistinct() {
        let periods = StatsCalculator.periodsInWindow(frequency: .weekly, days: 30, today: anchor)
        #expect(Set(periods).count == periods.count)
    }

    @Test func emptyEntriesRateIsZero() {
        let rate = StatsCalculator.completionRate(entries: [], frequency: .daily, days: 7, today: anchor)
        #expect(rate == 0.0)
    }

    @Test func allVerifiedRateIsOne() {
        let entries = (0..<7).map { verified($0) }
        let rate = StatsCalculator.completionRate(entries: entries, frequency: .daily, days: 7, today: anchor)
        #expect(rate == 1.0)
    }

    @Test func halfVerifiedRateIsHalf() {
        let entries = [0, 2, 4, 6].map { verified($0) }
        let rate = StatsCalculator.completionRate(entries: entries, frequency: .daily, days: 7, today: anchor)
        #expect(abs(rate - 4.0 / 7.0) < 0.001)
    }

    @Test func outOfWindowEntriesIgnored() {
        let old = StreakEntry(periodStart: day(35), status: .verified)
        let rate = StatsCalculator.completionRate(entries: [old], frequency: .daily, days: 30, today: anchor)
        #expect(rate == 0.0)
    }

    @Test func weeklyRate_twoEntriesSamePeriod_countAsOne() {
        // Two entries in the same week should count as a single hit
        let cal = Calendar.current
        let weekStart = Frequency.weekly.periodStart(for: anchor)
        // Two entries: one at the week start, one a day later — same period
        let e1 = StreakEntry(periodStart: weekStart, status: .verified)
        let e2 = StreakEntry(periodStart: cal.date(byAdding: .day, value: 1, to: weekStart)!, status: .verified)
        // periodsInWindow for weekly/30 from anchor gives N periods; only 1 is verified
        let periods = StatsCalculator.periodsInWindow(frequency: .weekly, days: 30, today: anchor)
        let rate = StatsCalculator.completionRate(entries: [e1, e2], frequency: .weekly, days: 30, today: anchor)
        // Exactly 1 of N weekly periods is hit
        #expect(abs(rate - 1.0 / Double(periods.count)) < 0.001)
    }

    @Test func monthlyRate_oneVerifiedMonth() {
        // anchor is 2024-01-15; monthly period start = 2024-01-01
        let monthStart = Frequency.monthly.periodStart(for: anchor)
        let entry = StreakEntry(periodStart: monthStart, status: .verified)
        let periods = StatsCalculator.periodsInWindow(frequency: .monthly, days: 30, today: anchor)
        let rate = StatsCalculator.completionRate(entries: [entry], frequency: .monthly, days: 30, today: anchor)
        #expect(abs(rate - 1.0 / Double(periods.count)) < 0.001)
    }
}
