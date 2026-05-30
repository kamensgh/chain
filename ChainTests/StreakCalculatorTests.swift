import Testing
import Foundation
@testable import Chain

struct StreakCalculatorTests {

    let cal = Calendar.current

    func day(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
    }

    func verified(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .verified)
    }

    func skipped(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .skipped)
    }

    @Test func emptyEntriesReturnsZero() {
        #expect(StreakCalculator.current(entries: [], frequency: .daily, today: Date()) == 0)
    }

    @Test func todayAloneIsStreakOf1() {
        #expect(StreakCalculator.current(entries: [verified(0)], frequency: .daily, today: Date()) == 1)
    }

    @Test func threeDaysConsecutiveIsStreakOf3() {
        let entries = [verified(0), verified(1), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date()) == 3)
    }

    @Test func missedDayBreaksStreak() {
        // days 0 and 2 verified, day 1 missing → streak is 1
        let entries = [verified(0), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date()) == 1)
    }

    @Test func longestSpansAcrossGap() {
        // streak of 3 (days 2,1,0), then a gap, then streak of 1 (day 10)
        let entries = [verified(0), verified(1), verified(2), verified(10)]
        #expect(StreakCalculator.longest(entries: entries, frequency: .daily) == 3)
    }

    @Test func gracePeriodCountsSkippedDay() {
        // day 2 verified, day 1 skipped (grace), day 0 verified → streak = 3
        let entries = [verified(0), skipped(1), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date(), gracePeriod: true) == 3)
    }

    @Test func gracePeriodOffSkippedBreaksStreak() {
        let entries = [verified(0), skipped(1), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date(), gracePeriod: false) == 1)
    }
}
