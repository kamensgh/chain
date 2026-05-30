import Foundation

struct VerificationResult {
    let status: EntryStatus
    let verifMethod: VerifMethod
    let value: Double?
    let sourceLabel: String
}

protocol HabitConnector {
    func verify(goalConfig: GoalConfig) async throws -> VerificationResult
}
