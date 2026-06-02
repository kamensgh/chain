import AppIntents
import SwiftData
import WidgetKit
import Foundation

struct VerifyHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Verify Habit"

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    func perform() async throws -> some IntentResult {
        guard let container = try? ModelContainerFactory.make(inAppGroup: true) else {
            return .result()
        }
        let ctx = ModelContext(container)
        let habits = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
        guard let habit = habits.first(where: { $0.id.uuidString == habitID }) else {
            return .result()
        }
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        let alreadyVerified = habit.entries.contains {
            $0.periodStart == period && $0.status == .verified
        }
        guard !alreadyVerified else { return .result() }
        let entry = HabitEntry(habit: habit, periodStart: period)
        entry.status = .verified
        entry.verifMethod = .manual
        entry.verifiedAt = Date()
        ctx.insert(entry)
        try? ctx.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
