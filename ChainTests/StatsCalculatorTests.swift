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

    @Test func weeklyWindowReturnsAtMost5() {
        let periods = StatsCalculator.periodsInWindow(frequency: .weekly, days: 30, today: anchor)
        #expect(periods.count >= 4)
        #expect(periods.count <= 5)
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
}
