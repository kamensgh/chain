# Chain UX Polish — Design Spec

**Date:** 2026-06-03  
**Scope:** Onboarding redesign, create-habit button, verification picker, settings padding

---

## 1. Onboarding — 5-step flow

### Step order

| # | Step | iOS | macOS |
|---|------|-----|-------|
| 1 | Welcome | ✅ | ✅ |
| 2 | Features tour | ✅ | ✅ |
| 3 | Companion picker | ✅ | ✅ |
| 4 | Permissions | ✅ | ✗ (skipped) |
| 5 | First habit | ✅ | ✅ |

`OnboardingStep` enum gains two new cases: `featureTour` and `companionPick`.

### Step 2: Features tour — `FeaturesTourStepView`

New file: `Chain/Views/Onboarding/FeaturesTourStepView.swift`

Black background, dot-indicator carousel, "Next →" button advances to companion picker.

**3 cards (in order):**

1. **✅ Verified automatically**  
   "Connect to Apple Health, take a screenshot, or use any data source. Chain proves you did it."

2. **🔥 Build unbreakable streaks**  
   "Every habit you complete extends your chain. Grace periods give you a safety net for off days."

3. **🐣 Your companion grows with you**  
   "Pick a pet, garden, or trophy room. Complete habits to level it up."

**Interaction:** Swipe left/right (`TabView` with `.page` style) or tap "Next →" to advance dot by dot. When on the last card "Next →" advances to the next onboarding step.

**State:** `@State private var cardIndex: Int = 0`. Button label is "Next →" on cards 0–1, "Continue →" on card 2.

### Step 3: Companion picker — `CompanionPickerStepView`

New file: `Chain/Views/Onboarding/CompanionPickerStepView.swift`

Black background. List of 3 tappable rows. Selected row highlighted with accent border + filled circle checkmark. "Let's go →" button disabled until selection made (default: first row pre-selected so button is always enabled).

**Rows:**

| Emoji | Title | Subtitle |
|-------|-------|----------|
| 🐣 | Pet | Egg → Baby → Juvenile → Adult → Legendary |
| 🌱 | Garden | Seedling → Sapling → Shrub → Tree → Ancient |
| 🏆 | Trophy Room | Collect trophies for every milestone |

**On confirm:** Set `companion.companionTypeRaw` on the existing `Companion` model record, then advance to next step. If no `Companion` exists yet in the model context, insert one with the chosen type before advancing.

---

## 2. Create habit button

### Today tab — zero habits state

Replace `ContentUnavailableView` in `TodayView` with a custom empty state:

```
[target emoji — large]
No habits yet
Start building your first chain.

[+ Create your first habit]  ← full-width accent button
```

Tapping opens `AddHabitView` in a sheet (same as the existing Habits tab `+` button).

**State needed:** `@State private var showingAddHabit = false` on `TodayView`.

### Today tab — has habits state

A floating action button (FAB) overlaid on the `ScrollView`:

- 56×56pt circle, accent background, white `+` at `.title2` weight
- Bottom-right, 20pt from safe area edges
- Shadow: `Color.accentColor.opacity(0.4)`, radius 12, y 4
- Implemented as a `ZStack` wrapping the `ScrollView` + a positioned `Button`
- Tapping opens the same `AddHabitView` sheet

### Habits tab

Keep the existing `ToolbarItem(placement: .primaryAction)` `+` button. No change needed — the Today entry points are now the primary UX.

---

## 3. Verification picker — 2-page Add Habit flow

### Architecture

`AddHabitView` gains `@State private var showingVerification = false`. Page 1 shows the basics form; tapping "Continue →" pushes page 2 via `NavigationStack` programmatic navigation (using a `NavigationPath` or a `@State private var path`).

**Alternative considered:** Sheet for page 2. Rejected — `NavigationStack` push feels more native for a sequential form and keeps the Cancel button working at the top level.

### Page 1 — Basics

Existing form content: name, emoji, frequency, reminder, grace period. Remove the Verification section (moved to page 2).

Toolbar: Cancel (left), no Save yet. Bottom of form: full-width "Continue →" button, disabled if name is empty.

### Page 2 — Verification (`VerificationPickerView`)

New file: `Chain/Views/Habits/VerificationPickerView.swift`

Navigation title: "How will you verify it?". Back button returns to page 1.

**Option rows** (tappable cards, selected row gets accent border):

| Emoji | Title | Subtitle | Platform |
|-------|-------|----------|----------|
| ✋ | Manual | Tap to mark done yourself | iOS + macOS |
| ❤️ | Apple Health | Steps, workouts, sleep — auto-verified | iOS only |
| 📸 | Screenshot | Upload a photo as proof | iOS only |
| 🔌 | MCP / Custom | Connect any data source via URL | iOS + macOS |

**Apple Health sub-picker:** When ❤️ is selected, an inline `Picker` appears below the card (segmented style): Steps / Workout minutes / Sleep hours. Maps to `ConnectorType.healthKitSteps/Workout/Sleep`.

**MCP URL field:** When 🔌 is selected, a `TextField("https://example.com/verify")` appears below the card.

**Save button:** Full-width at bottom. Disabled if MCP selected and URL is empty/invalid. Tapping creates or updates the habit and dismisses the sheet.

### Data flow

`VerificationPickerView` takes bindings:
```swift
@Binding var connectorType: ConnectorType
@Binding var connectorEndpoint: String
let onSave: () -> Void
```

`AddHabitView` holds these as `@State` and calls `save()` via the `onSave` closure.

---

## 4. Settings — remove padding

In `SettingsView`, remove the custom `.listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))` from the `CompanionSettingsView` row inside `Section("Companion")`. Let SwiftUI's default `Form` row insets apply.

Review `CompanionSettingsView` to ensure it doesn't add its own outer padding that would double up with the form row padding.

---

## Files to create

- `Chain/Views/Onboarding/FeaturesTourStepView.swift`
- `Chain/Views/Onboarding/CompanionPickerStepView.swift`
- `Chain/Views/Habits/VerificationPickerView.swift`

## Files to modify

- `Chain/Views/Onboarding/OnboardingView.swift` — add new steps to enum + switch
- `Chain/Views/Today/TodayView.swift` — empty state + FAB
- `Chain/Views/Habits/AddHabitView.swift` — 2-page flow, remove inline verification section
- `Chain/Views/Settings/SettingsView.swift` — remove custom listRowInsets
