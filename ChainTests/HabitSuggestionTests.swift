import Testing
import Foundation
@testable import ChainDomain

struct HabitSuggestionTests {

    @Test func buildPromptWithExistingHabits() {
        let prompt = HabitSuggestionHelpers.buildPrompt(existingNames: ["Run", "Read"])
        #expect(prompt.contains("Run"))
        #expect(prompt.contains("Read"))
        #expect(prompt.contains("3–5"))
    }

    @Test func buildPromptWithNoHabits() {
        let prompt = HabitSuggestionHelpers.buildPrompt(existingNames: [])
        #expect(prompt.contains("5"))
        #expect(!prompt.contains("already tracks"))
    }

    @Test func fallbackSuggestionsAreValid() {
        let suggestions = HabitSuggestionHelpers.fallbackSuggestions
        #expect(suggestions.count == 5)
        for s in suggestions {
            #expect(!s.name.isEmpty)
            #expect(!s.emoji.isEmpty)
            #expect(!s.reason.isEmpty)
        }
    }
}
