#if os(iOS)
import WatchConnectivity
import SwiftData
import WidgetKit
import Foundation

@Observable
final class PhoneWatchSession: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSession()
    private override init() { super.init() }

    private var container: ModelContainer?

    func activate(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSnapshot(habits: [Habit]) {
        guard WCSession.default.activationState == .activated else { return }
        let today = Date()
        let summaries: [WatchHabitSummary] = habits.map { habit in
            let entries = habit.entries.map {
                StreakEntry(periodStart: $0.periodStart, status: $0.status)
            }
            let isVerified = !HabitScheduler.isDue(
                frequency: habit.frequency, entries: entries, on: today)
            let streak = StreakCalculator.current(
                entries: entries, frequency: habit.frequency, today: today)
            return WatchHabitSummary(
                id: habit.id.uuidString,
                name: habit.name,
                emoji: habit.emoji,
                isVerifiedToday: isVerified,
                currentStreak: streak
            )
        }
        let payload = WatchPayload(habits: summaries, syncedAt: today)
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        try? WCSession.default.updateApplicationContext(dict)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleVerify(message)
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleVerify(userInfo)
    }

    // MARK: - Private

    private func handleVerify(_ dict: [String: Any]) {
        guard dict["action"] as? String == "verify",
              let habitID = dict["habitID"] as? String else { return }
        Task { @MainActor in
            guard let container else { return }
            let ctx = container.mainContext
            let habits = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
            guard let habit = habits.first(where: { $0.id.uuidString == habitID }) else { return }
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            let alreadyDone = habit.entries.contains {
                $0.periodStart == period && $0.status == .verified
            }
            guard !alreadyDone else { return }
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = .verified
            entry.verifMethod = .manual
            entry.verifiedAt = Date()
            ctx.insert(entry)
            try? ctx.save()
            WidgetCenter.shared.reloadAllTimelines()
            let updated = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
            sendSnapshot(habits: updated)
        }
    }
}
#endif
