# AI Habit Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface on-device AI-generated habit suggestions in the Habits list using iOS 18 Foundation Models, with a static fallback for unavailable devices.

**Architecture:** Pure-logic helpers live in `Chain/Models/` (SPM-testable). The Foundation Models actor lives in `Chain/AI/` (iOS-only, not compiled by `swift test`). A sheet UI in `Chain/Views/Habits/` calls the actor and shows suggestion cards; tapping "Add" pre-fills `AddHabitView`. Everything iOS-specific is guarded by `#if os(iOS)`.

**Tech Stack:** SwiftUI, iOS 18 FoundationModels framework, SwiftData, xcodegen (`project.yml`).

---

## Context

Chain habit-streak app — SwiftUI multiplatform macOS 14 + iOS 18, SwiftData, xcodegen. SPM `ChainDomain` target for pure domain tests.

Run tests with:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Baseline: **70 tests pass**. After Task 1: **73 tests pass**.

`Chain/AI/` directory is new — create it in Task 2.

`Chain/Models/HabitSuggestionHelpers.swift` is in the SPM `sources: ["Models"]` path and IS compiled by `swift test`.

`Chain/AI/HabitSuggestionService.swift` is NOT in any SPM source path and will NOT be compiled by `swift test`.

`#if os(iOS)` guards are used throughout this codebase for iOS-only code (see `Chain/WatchSession.swift`, `Chain/Views/Today/TodayView.swift`). Use the same pattern.

---

## File map

| File | Action |
|---|---|
| `Chain/Models/HabitSuggestionHelpers.swift` | Create — `SuggestedHabit` struct + `HabitSuggestionHelpers` enum (pure, SPM-testable) |
| `ChainTests/HabitSuggestionTests.swift` | Create — 3 SPM tests |
| `Chain/AI/HabitSuggestionService.swift` | Create — `@Generable` types + `HabitSuggestionService` actor (iOS only) |
| `Chain/Views/Habits/SuggestHabitsView.swift` | Create — suggestion sheet UI (iOS only) |
| `Chain/Views/Habits/AddHabitView.swift` | Modify — add `prefillName`/`prefillEmoji` vars, update `loadExisting()` |
| `Chain/Views/Habits/HabitsListView.swift` | Modify — add "✨ Suggest" toolbar button + two sheets (iOS only) |

---

## Task 1: HabitSuggestionHelpers + SPM tests

**Files:**
- Create: `Chain/Models/HabitSuggestionHelpers.swift`
- Create: `ChainTests/HabitSuggestionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `ChainTests/HabitSuggestionTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: FAIL — `HabitSuggestionHelpers` and `SuggestedHabit` not found.

- [ ] **Step 3: Create HabitSuggestionHelpers.swift**

Create `Chain/Models/HabitSuggestionHelpers.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **73 tests pass** (70 existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add Chain/Models/HabitSuggestionHelpers.swift ChainTests/HabitSuggestionTests.swift
git commit -m "feat: add HabitSuggestionHelpers and SPM tests"
```

---

## Task 2: HabitSuggestionService (iOS actor)

**Files:**
- Create: `Chain/AI/HabitSuggestionService.swift`

- [ ] **Step 1: Create the Chain/AI directory**

```bash
mkdir -p /Users/mac/Documents/projects/chain/Chain/AI
```

- [ ] **Step 2: Create HabitSuggestionService.swift**

Create `Chain/AI/HabitSuggestionService.swift`:

```swift
#if os(iOS)
import FoundationModels
import Foundation

@Generable
private struct GeneratedHabit {
    @Guide("A short, actionable habit name (2–4 words)")
    var name: String
    @Guide("A single emoji that represents this habit")
    var emoji: String
    @Guide("One sentence explaining why this habit complements the user's existing habits")
    var reason: String
}

@Generable
private struct GeneratedHabitList {
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
        return (habits, false)
    }
}
#endif
```

- [ ] **Step 3: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **73 tests pass** (no change — `Chain/AI/` is not in SPM sources).

- [ ] **Step 4: Run xcodegen to register Chain/AI/ with Xcode**

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: No errors. `HabitSuggestionService.swift` is now in the Chain Xcode target's Sources build phase.

- [ ] **Step 5: Commit**

```bash
git add Chain/AI/HabitSuggestionService.swift Chain.xcodeproj
git commit -m "feat: add HabitSuggestionService — on-device Foundation Models actor"
```

---

## Task 3: AddHabitView prefill

**Files:**
- Modify: `Chain/Views/Habits/AddHabitView.swift`

- [ ] **Step 1: Read the current file**

Read `Chain/Views/Habits/AddHabitView.swift` to confirm the current `loadExisting()` method before modifying.

- [ ] **Step 2: Add prefill properties**

In `AddHabitView`, add two new stored properties after `var habit: Habit? = nil`:

```swift
var prefillName: String = ""
var prefillEmoji: String = ""
```

The struct now has these properties, with matching default values so existing call sites (`AddHabitView()` and `AddHabitView(habit: h)`) are unaffected.

The complete top of the struct after the change:

```swift
struct AddHabitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var habit: Habit? = nil
    var prefillName: String = ""
    var prefillEmoji: String = ""

    @State private var name = ""
    @State private var emoji = "⭐"
    // ... rest unchanged
```

- [ ] **Step 3: Update loadExisting() to apply prefill**

Replace the existing `loadExisting()` method with:

```swift
private func loadExisting() {
    if let h = habit {
        name = h.name
        emoji = h.emoji
        frequency = h.frequency
        goalUnit = h.goalConfig.unit
        goalTarget = h.goalConfig.targetValue
        connectorType = h.connectorType
        gracePeriodEnabled = h.gracePeriodEnabled
        if let t = h.reminderTime {
            reminderEnabled = true
            reminderTime = t
        }
    } else {
        if !prefillName.isEmpty { name = prefillName }
        if !prefillEmoji.isEmpty { emoji = prefillEmoji }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **73 tests pass**.

- [ ] **Step 5: Commit**

```bash
git add Chain/Views/Habits/AddHabitView.swift
git commit -m "feat: add prefillName/prefillEmoji support to AddHabitView"
```

---

## Task 4: SuggestHabitsView + HabitsListView wiring

**Files:**
- Create: `Chain/Views/Habits/SuggestHabitsView.swift`
- Modify: `Chain/Views/Habits/HabitsListView.swift`

- [ ] **Step 1: Create SuggestHabitsView.swift**

Create `Chain/Views/Habits/SuggestHabitsView.swift`:

```swift
#if os(iOS)
import SwiftUI

private enum SuggestionState {
    case loading
    case loaded([SuggestedHabit], offline: Bool)
    case failed
}

struct SuggestHabitsView: View {
    let existingNames: [String]
    let onSelect: (SuggestedHabit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: SuggestionState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Thinking…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let suggestions, let offline):
                List {
                    ForEach(suggestions, id: \.name) { suggestion in
                        HStack(spacing: 12) {
                            Text(suggestion.emoji)
                                .font(.title2)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                    .font(.headline)
                                Text(suggestion.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                onSelect(suggestion)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                    if offline {
                        Text("Suggestions generated offline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }

            case .failed:
                VStack(spacing: 16) {
                    Text("Couldn't generate suggestions.")
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await load() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Suggested Habits")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let result = try await HabitSuggestionService.shared.suggest(existingNames: existingNames)
            state = .loaded(result.habits, offline: result.offline)
        } catch {
            state = .failed
        }
    }
}
#endif
```

- [ ] **Step 2: Read the current HabitsListView.swift**

Read `Chain/Views/Habits/HabitsListView.swift` to confirm the current structure before modifying.

- [ ] **Step 3: Update HabitsListView.swift**

Replace the entire contents of `Chain/Views/Habits/HabitsListView.swift` with:

```swift
import SwiftUI
import SwiftData

#if os(iOS)
private struct HabitPrefill: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
}
#endif

struct HabitsListView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    #if os(iOS)
    @State private var showingSuggest = false
    @State private var addPrefill: HabitPrefill? = nil
    #endif

    var body: some View {
        List {
            ForEach(habits) { habit in
                NavigationLink(destination: AddHabitView(habit: habit)) {
                    HStack(spacing: 10) {
                        Text(habit.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name).font(.subheadline.weight(.medium))
                            Text(habit.frequency.rawValue.capitalized + " · " + habit.connectorType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSuggest = true
                } label: {
                    Label("Suggest", systemImage: "sparkles")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddHabitView() }
        }
        #if os(iOS)
        .sheet(isPresented: $showingSuggest) {
            NavigationStack {
                SuggestHabitsView(existingNames: habits.map(\.name)) { selected in
                    showingSuggest = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        addPrefill = HabitPrefill(name: selected.name, emoji: selected.emoji)
                    }
                }
            }
        }
        .sheet(item: $addPrefill) { prefill in
            NavigationStack {
                AddHabitView(prefillName: prefill.name, prefillEmoji: prefill.emoji)
            }
        }
        #endif
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { habits[$0] }.forEach { context.delete($0) }
        try? context.save()
    }
}
```

- [ ] **Step 4: Run xcodegen to register SuggestHabitsView.swift**

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: No errors.

- [ ] **Step 5: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **73 tests pass**.

- [ ] **Step 6: Commit**

```bash
git add Chain/Views/Habits/SuggestHabitsView.swift Chain/Views/Habits/HabitsListView.swift Chain.xcodeproj
git commit -m "feat: add AI habit suggestions — sparkles toolbar button, suggestion sheet, prefill flow"
```

---

## Self-review

**Spec coverage:**
- ✅ `SuggestedHabit` plain struct in `Chain/Models/` — SPM-testable
- ✅ `HabitSuggestionHelpers.buildPrompt` — pure, tested
- ✅ `HabitSuggestionHelpers.fallbackSuggestions` — 5 curated items, tested
- ✅ `HabitSuggestionService` actor — iOS-only, `@Generable` types, availability check, offline flag
- ✅ `SuggestHabitsView` — loading / loaded (with offline note) / failed states
- ✅ `AddHabitView` prefill via `prefillName`/`prefillEmoji` vars + `loadExisting()` update
- ✅ `HabitsListView` — "✨ Suggest" toolbar button (iOS), two-sheet flow
- ✅ macOS unaffected — all new iOS code behind `#if os(iOS)`

**Type consistency:**
- `SuggestedHabit` defined in Task 1, used in Tasks 2, 3, 4 — consistent
- `HabitSuggestionHelpers.buildPrompt(existingNames:)` defined in Task 1, used in Task 2 — consistent
- `HabitSuggestionService.shared.suggest(existingNames:)` returns `(habits: [SuggestedHabit], offline: Bool)` — used correctly in `SuggestHabitsView.load()`

**No placeholders found.**
