# AI Habit Suggestions — Design Spec
**Date:** 2026-06-02
**Status:** Approved

---

## Overview

Surface AI-generated habit suggestions inside the Habits list. The user taps "✨ Suggest" in the toolbar, a sheet appears with 3–5 habit cards generated on-device by iOS 18 Foundation Models, and tapping "Add" on any card opens `AddHabitView` pre-filled with the suggested name and emoji.

Feature is iOS-only (`#if os(iOS)`). macOS is unaffected.

---

## Platform targets

| Platform | Deployment target |
|---|---|
| iOS | 18.0 (unchanged) |
| macOS | 14.0 (unchanged, feature not present) |

---

## Architecture

Three new files plus one modification:

| File | Action | Purpose |
|---|---|---|
| `Chain/AI/HabitSuggestionService.swift` | Create | `@Generable` types + `HabitSuggestionService` actor |
| `Chain/Views/Habits/SuggestHabitsView.swift` | Create | Sheet UI — loading, suggestion cards, unavailable state |
| `Chain/Views/Habits/AddHabitView.swift` | Modify | Add `init(prefillName:prefillEmoji:)` for pre-filling from suggestion |
| `Chain/Views/Habits/HabitsListView.swift` | Modify | Add "✨ Suggest" toolbar button (iOS only) + sheet wiring |

---

## HabitSuggestionService

File: `Chain/AI/HabitSuggestionService.swift`, wrapped entirely in `#if os(iOS)`.

### Structured output types

```swift
import FoundationModels

@Generable
struct SuggestedHabit {
    @Guide("A short, actionable habit name (2–4 words)")
    var name: String
    @Guide("A single emoji that represents this habit")
    var emoji: String
    @Guide("One sentence explaining why this habit complements the user's existing habits")
    var reason: String
}

@Generable
struct HabitSuggestionList {
    @Guide("Between 3 and 5 habit suggestions the user does not already track")
    var habits: [SuggestedHabit]
}
```

### Service actor

```swift
actor HabitSuggestionService {
    static let shared = HabitSuggestionService()

    func suggest(existingNames: [String]) async throws -> [SuggestedHabit]
}
```

**Logic:**
1. Check `SystemLanguageModel.default.availability`. If `.unavailable`, return `HabitSuggestionService.fallbackSuggestions`.
2. Build prompt:
   - If `existingNames.isEmpty`: `"Suggest 5 popular daily habits for someone just starting a healthy routine."`
   - Otherwise: `"The user already tracks: \(existingNames.joined(separator: ", ")). Suggest 3–5 new complementary daily habits they don't already track. Keep names short and actionable."`
3. Create `LanguageModelSession()`, call `session.respond(to: prompt, generating: HabitSuggestionList.self)`.
4. Return `response.content.habits`.

### Static fallback

When the model is unavailable, return these 5 curated suggestions:

```swift
static let fallbackSuggestions: [SuggestedHabit] = [
    SuggestedHabit(name: "Morning walk", emoji: "🚶", reason: "Light daily movement improves energy and mood."),
    SuggestedHabit(name: "Read 20 minutes", emoji: "📚", reason: "Daily reading builds focus and vocabulary over time."),
    SuggestedHabit(name: "Drink 8 glasses of water", emoji: "💧", reason: "Proper hydration supports every system in your body."),
    SuggestedHabit(name: "Meditate 5 minutes", emoji: "🧘", reason: "Short daily meditation reduces stress and sharpens focus."),
    SuggestedHabit(name: "Journal one page", emoji: "📝", reason: "Writing daily clarifies thinking and tracks personal growth.")
]
```

---

## SuggestHabitsView

File: `Chain/Views/Habits/SuggestHabitsView.swift`.

Sheet that takes `existingNames: [String]` as input.

### States

```swift
enum SuggestionState {
    case loading
    case loaded([SuggestedHabit])
    case unavailable         // model unavailable — shows fallback
    case failed(String)      // generation error — shows retry
}
```

### Layout

**Loading:** `ProgressView("Thinking…")` centered.

**Loaded / unavailable:** `List` of suggestion cards. Each card:
- Leading: emoji in large font
- Title: habit name (`.headline`)
- Subtitle: reason (`.caption`, secondary color)
- Trailing: "Add" button — calls `onSelect(SuggestedHabit)` closure and dismisses sheet

**Failed:** Error message + "Try again" button that re-triggers generation.

**Header:** Navigation title "Suggested Habits". Toolbar "Done" button to dismiss without selecting.

### Unavailable label

When using the fallback, show a small note below the list: `"Suggestions generated offline"` in secondary caption style.

---

## AddHabitView changes

Add a new initializer that accepts pre-fill values:

```swift
init(prefillName: String = "", prefillEmoji: String = "⭐") {
    _name = State(initialValue: prefillName)
    _emoji = State(initialValue: prefillEmoji)
}
```

The existing `init()` (no args) and `init(habit: Habit)` are unchanged.

---

## HabitsListView changes

iOS-only changes:

```swift
#if os(iOS)
@State private var showingSuggest = false
@State private var suggestPrefill: (name: String, emoji: String)?
#endif
```

Toolbar addition (inside existing `.toolbar` block):

```swift
#if os(iOS)
Button {
    showingSuggest = true
} label: {
    Label("Suggest", systemImage: "sparkles")
}
#endif
```

Sheet:

```swift
#if os(iOS)
.sheet(isPresented: $showingSuggest) {
    SuggestHabitsView(existingNames: habits.map(\.name)) { selected in
        suggestPrefill = (selected.name, selected.emoji)
        showingSuggest = false
    }
}
.sheet(item: $suggestPrefill) { prefill in
    NavigationStack {
        AddHabitView(prefillName: prefill.name, prefillEmoji: prefill.emoji)
    }
}
#endif
```

Note: `suggestPrefill` uses `.sheet(item:)` so it fires after `showingSuggest` dismisses. The tuple must conform to `Identifiable` — wrap in a small struct `HabitPrefill: Identifiable`.

---

## Error handling

| Scenario | Behaviour |
|---|---|
| `SystemLanguageModel.default.availability == .unavailable` | Show static fallback list with "Suggestions generated offline" note |
| `session.respond` throws | Show `.failed` state with "Couldn't generate suggestions. Try again." |
| User has 0 habits | Adjusted prompt: "Suggest 5 popular starter habits" |
| User taps "Done" without selecting | Sheet dismisses, nothing changes |

---

## Testing

Foundation Models requires hardware and is not unit-testable via `swift test`. The following are testable:

- `HabitSuggestionService.buildPrompt(existingNames:)` — static function, pure string output
- `HabitSuggestionService.fallbackSuggestions` — assert count == 5, all fields non-empty

Add 2 SPM tests to `ChainTests/HabitSuggestionTests.swift`. Baseline before this feature: 70 tests. Target after: 72.

---

## project.yml / Package.swift changes

None required. `FoundationModels` is a system framework available on iOS 18 — no new SDK entries needed in `project.yml`. SPM `Package.swift` sources `Chain/AI/` via the existing `Chain` source path in the Xcode target (xcodegen picks it up automatically from the `Chain` directory source path).

The SPM `ChainDomain` target sources `Chain/Domain`, `Chain/Connectors`, `Chain/Models` — **not** `Chain/AI/`. `HabitSuggestionService.swift` will live in `Chain/AI/` and is therefore compiled by Xcode but **not** by `swift test`. The test file `ChainTests/HabitSuggestionTests.swift` must only test the pure functions (`buildPrompt`, `fallbackSuggestions`) that don't import `FoundationModels` — or the test file must be wrapped in `#if canImport(FoundationModels)`.

Simplest approach: extract `buildPrompt` and `fallbackSuggestions` as `internal static` functions on `HabitSuggestionService`, move them to `Chain/Models/HabitSuggestionHelpers.swift` (in the SPM sources path), test those. The `FoundationModels`-dependent code stays in `Chain/AI/`.

---

## File map (revised for testability)

| File | Action | Purpose |
|---|---|---|
| `Chain/Models/HabitSuggestionHelpers.swift` | Create | `SuggestedHabit` struct (plain Codable, no `@Generable`), `buildPrompt`, `fallbackSuggestions` — SPM-testable |
| `Chain/AI/HabitSuggestionService.swift` | Create | `@Generable` wrappers + `HabitSuggestionService` actor (iOS only, imports FoundationModels) |
| `Chain/Views/Habits/SuggestHabitsView.swift` | Create | Sheet UI |
| `Chain/Views/Habits/AddHabitView.swift` | Modify | Add `init(prefillName:prefillEmoji:)` |
| `Chain/Views/Habits/HabitsListView.swift` | Modify | Add toolbar button + sheets (iOS only) |
| `ChainTests/HabitSuggestionTests.swift` | Create | 2 tests: buildPrompt output, fallbackSuggestions validity |
