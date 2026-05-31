import Foundation
import SwiftData
import HealthKit

final class ConnectorService {
    static let shared = ConnectorService()
    private init() {}

    func verify(habit: Habit, context: ModelContext) async {
        guard let connector = makeConnector(for: habit) else { return }
        do {
            let result = try await connector.verify(goalConfig: habit.goalConfig)
            await MainActor.run { applyResult(result, to: habit, context: context) }
        } catch {
            // Network / HealthKit permission failures are normal — don't surface them as crashes
        }
    }

    // MARK: - Factory

    private func makeConnector(for habit: Habit) -> (any HabitConnector)? {
        switch habit.connectorType {
        case .manual:
            return ManualConnector()
        case .screenshot:
            return nil  // Screenshot-type habits are verified through ScreenshotPickerView, not here
        case .mcp:
            guard let endpointStr = habit.connectorEndpoint,
                  let url = URL(string: endpointStr) else { return nil }
            let credential = KeychainHelper.load(for: habit.id.uuidString)
            return MCPConnector(endpoint: url, credential: credential)
        case .healthKitSteps:
            return HealthKitConnector(store: HKHealthStore(), dataType: .steps)
        case .healthKitWorkout:
            return HealthKitConnector(store: HKHealthStore(), dataType: .workoutMinutes)
        case .healthKitSleep:
            return HealthKitConnector(store: HKHealthStore(), dataType: .sleepHours)
        }
    }

    // MARK: - Result application (must run on MainActor)

    @MainActor
    private func applyResult(_ result: VerificationResult, to habit: Habit, context: ModelContext) {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
            guard existing.status != .verified else { return }
            existing.status = result.status
            existing.verifMethod = result.verifMethod
            existing.value = result.value
            existing.sourceLabel = result.sourceLabel
            existing.verifiedAt = result.status == .verified ? Date() : nil
        } else {
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = result.status
            entry.verifMethod = result.verifMethod
            entry.value = result.value
            entry.sourceLabel = result.sourceLabel
            entry.verifiedAt = result.status == .verified ? Date() : nil
            context.insert(entry)
        }
        try? context.save()

        guard result.status == .verified else { return }
        let streakEntries = habit.entries.map {
            StreakEntry(periodStart: $0.periodStart, status: $0.status)
        }
        let streak = StreakCalculator.current(
            entries: streakEntries,
            frequency: habit.frequency,
            today: Date(),
            gracePeriod: habit.gracePeriodEnabled
        )
        guard let milestone = MilestoneChecker.milestone(for: streak) else { return }
        Task { await NotificationScheduler.scheduleMilestone(for: habit, streak: milestone) }
    }
}
