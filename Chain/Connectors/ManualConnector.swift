import Foundation

struct ManualConnector: HabitConnector {
    func verify(goalConfig: GoalConfig) async throws -> VerificationResult {
        VerificationResult(status: .verified, verifMethod: .manual, value: nil, sourceLabel: "Manual")
    }
}
