import Testing
import Foundation
@testable import ChainDomain

struct HabitSchedulerTests {

    let cal = Calendar.current

    @Test func dailyPeriodStartIsStartOfDay() {
        let date = Date()
        #expect(HabitScheduler.periodStart(for: .daily, on: date) == cal.startOfDay(for: date))
    }

    @Test func weeklyPeriodStartIsStartOfWeek() {
        let date = Date()
        #expect(HabitScheduler.periodStart(for: .weekly, on: date) == cal.dateInterval(of: .weekOfYear, for: date)!.start)
    }

    @Test func monthlyPeriodStartIsStartOfMonth() {
        let date = Date()
        #expect(HabitScheduler.periodStart(for: .monthly, on: date) == cal.dateInterval(of: .month, for: date)!.start)
    }

    @Test func isDueTrueWhenNoEntries() {
        #expect(HabitScheduler.isDue(frequency: .daily, entries: [], on: Date()) == true)
    }

    @Test func isDueFalseWhenVerifiedEntryExists() {
        let today = cal.startOfDay(for: Date())
        let entry = StreakEntry(periodStart: today, status: .verified)
        #expect(HabitScheduler.isDue(frequency: .daily, entries: [entry], on: Date()) == false)
    }

    @Test func isDueTrueWhenEntryIsPending() {
        let today = cal.startOfDay(for: Date())
        let entry = StreakEntry(periodStart: today, status: .pending)
        #expect(HabitScheduler.isDue(frequency: .daily, entries: [entry], on: Date()) == true)
    }

    @Test func entryForTodayReturnsCorrectEntry() {
        let today = cal.startOfDay(for: Date())
        let entry = StreakEntry(periodStart: today, status: .verified)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let old = StreakEntry(periodStart: yesterday, status: .verified)
        #expect(HabitScheduler.entry(for: .daily, entries: [entry, old], on: Date())?.periodStart == today)
    }
}
