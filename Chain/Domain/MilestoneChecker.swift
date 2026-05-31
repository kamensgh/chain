import Foundation

enum MilestoneChecker {
    static let milestones: Set<Int> = [7, 14, 30, 60, 100]

    /// Returns the milestone if `streak` is exactly one of the milestone values, nil otherwise.
    static func milestone(for streak: Int) -> Int? {
        milestones.contains(streak) ? streak : nil
    }
}
