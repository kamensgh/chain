// ChainTests/CompanionEngineTests.swift
import Testing
import Foundation
@testable import ChainDomain

struct CompanionEngineTests {

    let cal = Calendar.current

    func day(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
    }

    func verified(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .verified)
    }

    // MARK: needState

    @Test func fedWhenTodayVerified() {
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(0)], frequency: .daily, now: now)
        #expect(state == .fed)
    }

    @Test func peckishWhenNewHabitNoEntries() {
        // No history at all → not sick yet, just peckish
        let now = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [], frequency: .daily, now: now)
        #expect(state == .peckish)
    }

    @Test func sickWhenYesterdayMissedAndHasHistory() {
        // Has an older entry (history exists) but yesterday was not verified
        let twoDaysAgo = StreakEntry(periodStart: day(2), status: .verified)
        let now = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [twoDaysAgo], frequency: .daily, now: now)
        #expect(state == .sick)
    }

    @Test func hungryAfter6pm() {
        let now = cal.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        // Yesterday was verified, today not done yet
        let state = CompanionEngine.needState(for: .food, entries: [verified(1)], frequency: .daily, now: now)
        #expect(state == .hungry)
    }

    @Test func starvingAfter9pm() {
        let now = cal.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(1)], frequency: .daily, now: now)
        #expect(state == .starving)
    }

    @Test func peckishBefore6pm() {
        let now = cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(1)], frequency: .daily, now: now)
        #expect(state == .peckish)
    }

    @Test func weeklyHabitPeckishWhenInSamePeriod() {
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(7)], frequency: .weekly, now: now)
        #expect(state != .fed)  // not done this week
    }

    // MARK: stage

    @Test func stage0IsEgg() {
        #expect(CompanionEngine.stage(xp: 0) == .egg)
    }

    @Test func stage50IsBaby() {
        #expect(CompanionEngine.stage(xp: 50) == .baby)
    }

    @Test func stage200IsJuvenile() {
        #expect(CompanionEngine.stage(xp: 200) == .juvenile)
    }

    @Test func stage500IsAdult() {
        #expect(CompanionEngine.stage(xp: 500) == .adult)
    }

    @Test func stage1000IsLegendary() {
        #expect(CompanionEngine.stage(xp: 1000) == .legendary)
    }

    @Test func stageBelowFloorIsLower() {
        #expect(CompanionEngine.stage(xp: 49) == .egg)
        #expect(CompanionEngine.stage(xp: 199) == .baby)
    }

    // MARK: xpDelta

    @Test func noNeedsReturnsZero() {
        #expect(CompanionEngine.xpDelta(needStates: []) == 0)
    }

    @Test func allSickReturnsMinus5() {
        #expect(CompanionEngine.xpDelta(needStates: [.sick]) == -5)
        #expect(CompanionEngine.xpDelta(needStates: [.sick, .sick]) == -5)
    }

    @Test func oneNeedFedReturns10() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed]) == 10)
    }

    @Test func twoNeedsFedReturns15() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed, .fed]) == 15)
    }

    @Test func threeNeedsFedReturns20() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed, .fed, .fed]) == 20)
    }

    @Test func mixedFedAndHungryCountsFed() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed, .hungry]) == 10)
    }

    // MARK: trophies

    @Test func noTrophiesForShortStreak() {
        let entries = [StreakEntry(periodStart: Calendar.current.startOfDay(for: Date()), status: .verified)]
        let result = CompanionEngine.trophies(habits: [(name: "Run", entries: entries, frequency: .daily)], today: Date())
        #expect(result.isEmpty)
    }

    @Test func bronzeTrophyAt7Days() {
        let entries = (0..<7).map { StreakEntry(periodStart: Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date()))!, status: .verified) }
        let result = CompanionEngine.trophies(habits: [(name: "Run", entries: entries, frequency: .daily)], today: Date())
        #expect(result.contains { $0.tier == .bronze && $0.habitName == "Run" })
    }
}
