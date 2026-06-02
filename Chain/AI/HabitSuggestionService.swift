#if os(iOS)
import FoundationModels
import Foundation

@Generable
struct GeneratedHabit {
    @Guide("A short, actionable habit name (2–4 words)")
    var name: String
    @Guide("A single emoji that represents this habit")
    var emoji: String
    @Guide("One sentence explaining why this habit complements the user's existing habits")
    var reason: String
}

@Generable
struct GeneratedHabitList {
    @Guide("Between 3 and 5 habit suggestions the user does not already track")
    var habits: [GeneratedHabit]
}

actor HabitSuggestionService {
    static let shared = HabitSuggestionService()

    func suggest(existingNames: [String]) async throws -> (habits: [SuggestedHabit], offline: Bool) {
        guard case .available = SystemLanguageModel.default.availability else {
            return (HabitSuggestionHelpers.fallbackSuggestions, true)
        }
        let prompt = HabitSuggestionHelpers.buildPrompt(existingNames: existingNames)
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt, generating: GeneratedHabitList.self)
        let habits = response.content.habits.map {
            SuggestedHabit(name: $0.name, emoji: $0.emoji, reason: $0.reason)
        }
        guard !habits.isEmpty else {
            return (HabitSuggestionHelpers.fallbackSuggestions, true)
        }
        return (habits, false)
    }
}
#endif
