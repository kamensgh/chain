import Testing
import Foundation
@testable import ChainDomain

struct WatchPayloadTests {

    @Test func roundTripWithHabits() throws {
        let summary = WatchHabitSummary(
            id: "abc", name: "Run", emoji: "🏃",
            isVerifiedToday: true, currentStreak: 7
        )
        let payload = WatchPayload(
            habits: [summary],
            syncedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(WatchPayload.self, from: data)
        #expect(decoded.habits.count == 1)
        #expect(decoded.habits[0].id == "abc")
        #expect(decoded.habits[0].name == "Run")
        #expect(decoded.habits[0].isVerifiedToday == true)
        #expect(decoded.habits[0].currentStreak == 7)
        #expect(decoded.verifiedCount == 1)
        #expect(decoded.totalCount == 1)
    }

    @Test func emptyPayloadRoundTrip() throws {
        let payload = WatchPayload(habits: [], syncedAt: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(WatchPayload.self, from: data)
        #expect(decoded.habits.isEmpty)
        #expect(decoded.verifiedCount == 0)
        #expect(decoded.totalCount == 0)
    }
}
