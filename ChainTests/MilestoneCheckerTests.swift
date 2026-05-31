import Testing
@testable import ChainDomain

struct MilestoneCheckerTests {

    @Test func milestone7()   { #expect(MilestoneChecker.milestone(for: 7)   == 7)   }
    @Test func milestone14()  { #expect(MilestoneChecker.milestone(for: 14)  == 14)  }
    @Test func milestone30()  { #expect(MilestoneChecker.milestone(for: 30)  == 30)  }
    @Test func milestone60()  { #expect(MilestoneChecker.milestone(for: 60)  == 60)  }
    @Test func milestone100() { #expect(MilestoneChecker.milestone(for: 100) == 100) }
    @Test func nonMilestone1()  { #expect(MilestoneChecker.milestone(for: 1)  == nil) }
    @Test func nonMilestone15() { #expect(MilestoneChecker.milestone(for: 15) == nil) }
    @Test func zero()           { #expect(MilestoneChecker.milestone(for: 0)  == nil) }
}
