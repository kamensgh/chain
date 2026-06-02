import Foundation

struct SuggestedHabit: Equatable {
    let name: String
    let emoji: String
    let reason: String
}

enum HabitSuggestionHelpers {
    static func buildPrompt(existingNames: [String]) -> String {
        if existingNames.isEmpty {
            return "Suggest 5 popular daily habits for someone just starting a healthy routine. Keep names short and actionable (2–4 words)."
        }
        let list = existingNames.joined(separator: ", ")
        return "The user already tracks: \(list). Suggest 3–5 new complementary daily habits they don't already track. Keep names short and actionable (2–4 words)."
    }

    static let fallbackSuggestions: [SuggestedHabit] = [
        SuggestedHabit(name: "Morning walk",             emoji: "🚶", reason: "Light daily movement improves energy and mood."),
        SuggestedHabit(name: "Read 20 minutes",          emoji: "📚", reason: "Daily reading builds focus and vocabulary over time."),
        SuggestedHabit(name: "Drink 8 glasses of water", emoji: "💧", reason: "Proper hydration supports every system in your body."),
        SuggestedHabit(name: "Meditate 5 minutes",       emoji: "🧘", reason: "Short daily meditation reduces stress and sharpens focus."),
        SuggestedHabit(name: "Journal one page",         emoji: "📝", reason: "Writing daily clarifies thinking and tracks personal growth.")
    ]
}
