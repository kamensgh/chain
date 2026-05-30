import HealthKit
import Foundation

struct HealthKitConnector: HabitConnector {

    enum DataType { case steps, workoutMinutes, sleepHours }

    let store: HKHealthStore
    let dataType: DataType

    func verify(goalConfig: GoalConfig) async throws -> VerificationResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            return VerificationResult(status: .pending, verifMethod: .auto, value: nil, sourceLabel: "Health unavailable")
        }
        switch dataType {
        case .steps:          return try await verifySteps(goalConfig: goalConfig)
        case .workoutMinutes: return try await verifyWorkout(goalConfig: goalConfig)
        case .sleepHours:     return try await verifySleep(goalConfig: goalConfig)
        }
    }

    // MARK: - Steps

    private func verifySteps(goalConfig: GoalConfig) async throws -> VerificationResult {
        let type = HKQuantityType(.stepCount)
        try await store.requestAuthorization(toShare: [], read: [type])

        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                let steps = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: VerificationResult(
                    status: steps >= goalConfig.targetValue ? .verified : .pending,
                    verifMethod: .auto,
                    value: steps,
                    sourceLabel: "Apple Health · \(Int(steps).formatted()) steps"
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - Workout

    private func verifyWorkout(goalConfig: GoalConfig) async throws -> VerificationResult {
        let type = HKObjectType.workoutType()
        try await store.requestAuthorization(toShare: [], read: [type])

        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let minutes = (samples as? [HKWorkout])?
                    .reduce(0.0) { $0 + $1.duration / 60 } ?? 0
                cont.resume(returning: VerificationResult(
                    status: minutes >= goalConfig.targetValue ? .verified : .pending,
                    verifMethod: .auto,
                    value: minutes,
                    sourceLabel: "Apple Health · \(Int(minutes)) min workout"
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    private func verifySleep(goalConfig: GoalConfig) async throws -> VerificationResult {
        let type = HKCategoryType(.sleepAnalysis)
        try await store.requestAuthorization(toShare: [], read: [type])

        let cal = Calendar.current
        let now = Date()
        // Count sleep from yesterday 8pm → today noon
        let todayNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterday8pm = cal.date(bySettingHour: 20, minute: 0, second: 0, of: yesterday)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday8pm, end: todayNoon)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let hours = (samples as? [HKCategorySample])?
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 } ?? 0
                cont.resume(returning: VerificationResult(
                    status: hours >= goalConfig.targetValue ? .verified : .pending,
                    verifMethod: .auto,
                    value: hours,
                    sourceLabel: "Apple Health · \(String(format: "%.1f", hours))h sleep"
                ))
            }
            store.execute(query)
        }
    }
}
