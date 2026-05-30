# Chain Companion System — Design Spec
**Date:** 2026-05-30
**Status:** Approved

---

## Overview

The Companion System adds a motivational character to Chain that lives and grows alongside the user's habits. Completing habits keeps the companion healthy and helps it evolve. Missing habits makes it sad, then sick. The companion appears in the Today tab and in the macOS menu bar popover, staying visible as a constant (but gentle) motivator.

Users choose one of three companion types in Settings. All three share the same XP and need mechanics but present different visual themes.

---

## Companion Types

| Type | Theme | Needs mapped to |
|---|---|---|
| 🐾 Pet | Tamagotchi creature | Food · Water · Exercise |
| 🌱 Garden | Living plant | Watering · Sunlight · Fertilizing |
| 🏆 Trophy Room | Achievement shelf | No death mechanic — purely additive |

**One companion type is active at a time.** The user picks in Settings; switching keeps existing XP and accessories.

---

## Habit → Need Mapping

Habits are assigned to companion needs automatically by creation order. This is global — the same first habit feeds the companion regardless of which companion type is active.

| Position | Pet need | Garden need |
|---|---|---|
| 1st habit created | Food 🍖 | Watering 💧 |
| 2nd habit created | Water 🫧 | Sunlight ☀️ |
| 3rd habit created | Exercise 🏃 | Fertilizing 🌿 |
| 4th+ habits | No companion role | No companion role |

Only the first habit is required. The 2nd and 3rd are optional but accelerate growth. When fewer than 3 habits exist, `CompanionCardView` shows a soft prompt beneath the need indicators: "Add a water habit to help your companion grow faster! ➕" (tapping navigates to Add Habit). The app never blocks or nags — one prompt, always dismissible.

Trophy Room ignores this mapping — all habits contribute equally to XP.

---

## Need States

Each of the three companion needs independently tracks its own state based on whether today's habit was completed and how much time remains in the day.

| State | Trigger | Description |
|---|---|---|
| `fed` | Completed today | Need satisfied |
| `peckish` | Not done, before 6 pm | Mild, no urgency |
| `hungry` | Not done, 6 pm–9 pm | Noticeable — companion looks concerned |
| `starving` | Not done, 9 pm–midnight | Urgent — companion visibly distressed |
| `sick` | Missed a full period (24 h passed without completion) | Companion is ill |
| `recovering` | Double-task revival submitted | Companion is healing |

**Overall companion health** is the worst of its three active need states. A companion with food=fed, water=hungry, exercise=sick is overall `sick`.

---

## Revival

When a need is `sick`, the user can revive it by completing double the habit's goal value within the next period:

- Boolean habit: tap done twice (two manual check-ins in one day)
- Steps habit: log double the step target
- Minutes habit: log double the minute target

On revival, the need transitions to `recovering` (sparkle animation plays), then to `fed` at the next successful completion. XP penalty from the sick day is not refunded — revival just stops the bleeding.

---

## Growth & XP

### XP per day
| Habits completed | XP earned |
|---|---|
| 0 | −5 (sick day) |
| Habit 1 only | +10 |
| Habits 1 + 2 | +15 |
| Habits 1 + 2 + 3 | +20 |

XP is cumulative. Sick days subtract 5 XP but cannot drop XP below the current stage's floor — the companion cannot de-evolve.

### Pet & Garden stages

| Stage | XP floor | Accessory unlocked |
|---|---|---|
| Egg / Seed | 0 | — |
| Baby / Sprout | 50 | Collar / Fence |
| Juvenile / Bush | 200 | Hat / Bees |
| Adult / Bloom | 500 | Cape / Butterflies |
| Legendary / Paradise | 1 000 | Crown / Rainbow |

Stage transitions trigger a spring-bounce scale animation + confetti burst.

### Trophy Room milestones
Trophy Room has no stages. Instead, trophies are awarded at combined streak milestones across all habits:

| Milestone | Trophy |
|---|---|
| Any habit hits 7-day streak | Bronze trophy |
| Any habit hits 14-day streak | Silver trophy |
| Any habit hits 30-day streak | Gold trophy |
| Any habit hits 60-day streak | Platinum trophy |
| Any habit hits 100-day streak | Diamond trophy |

Multiple trophies of the same tier can accumulate (one per habit). The shelf renders up to 9 trophies before scrolling.

---

## Architecture

### Domain layer (SPM-testable, no SwiftUI/SwiftData)

**`Chain/Domain/CompanionEngine.swift`**

Pure stateless enum. All inputs come from the call site; no stored state.

```swift
enum CompanionEngine {
    // Returns the NeedState for one companion need based on today's entries and current time
    static func needState(
        for need: CompanionNeed,
        entries: [StreakEntry],
        now: Date
    ) -> NeedState

    // Maps accumulated XP to a PetStage
    static func stage(xp: Double) -> PetStage

    // XP delta for a given day based on how many needs were fed (0, 1, 2, or 3)
    // Returns negative value on sick day (all needs sick)
    static func xpDelta(needStates: [NeedState]) -> Double

    // Trophies earned based on all habit streak entries
    static func trophies(habitEntries: [[StreakEntry]], frequency: Frequency) -> [Trophy]
}
```

Supporting types (also in domain layer, SPM-testable):

```swift
enum CompanionType: String, Codable, CaseIterable { case pet, garden, trophyRoom }
enum CompanionNeed: String, Codable { case food, water, exercise }
enum NeedState { case fed, peckish, hungry, starving, sick, recovering }
enum PetStage: String, Codable, CaseIterable {
    case egg, baby, juvenile, adult, legendary
    var xpFloor: Double { /* 0, 50, 200, 500, 1000 */ }
    var accessory: String? { /* nil, "collar", "hat", "cape", "crown" */ }
}
struct Trophy { let tier: TrophyTier; let habitName: String }
enum TrophyTier { case bronze, silver, gold, platinum, diamond }
```

### SwiftData model

**`Chain/Models/Companion.swift`**

One record per user. Synced to CloudKit alongside Habit and HabitEntry.

```swift
@Model final class Companion {
    @Attribute(.unique) var id: UUID
    var typeRaw: String          // CompanionType raw value
    var xp: Double
    var accessoriesUnlocked: [String]   // PetStage raw values that have been unlocked
    var createdAt: Date

    var companionType: CompanionType { get/set }
}
```

Stage and NeedState are never stored — always computed from `xp` and `HabitEntry` history.

`ChainApp` adds `Companion.self` to the `ModelContainer` schema.

### UI layer

**`Chain/Views/Companion/CompanionCardView.swift`**

Full companion card shown in the Today tab above the habit list.

- Large character emoji (~80 pt) with accessory overlays
- Stage name + XP progress bar
- Row of 3 need indicators (filled/dimmed based on NeedState)
- Idle float via `PhaseAnimator` (2-second cycle, ±4 pt vertical)
- State animations: sick → grey tint + slow pulse; starving → fast horizontal shake; recovering → sparkle overlay
- Stage transition: spring scale-up + confetti

**`Chain/Views/Companion/CompanionMenuBarView.swift`**

Compact companion for the macOS menu bar popover header.

- Small emoji (~28 pt) with a colored health dot (green/yellow/orange/red/grey)
- Same idle bob animation at reduced amplitude

**`Chain/Views/Settings/CompanionSettingsView.swift`**

Three selectable cards (Pet / Garden / Trophy Room) showing each companion in its happy default state. Selecting one updates `companion.type` immediately.

---

## Character Representation

Each stage × health combination maps to a base emoji + optional overlay emoji:

### Pet

| Stage | Base | Sick overlay | Recovering overlay |
|---|---|---|---|
| Egg | 🥚 | 🤒 | ✨ |
| Baby | 🐣 | 🤒 | ✨ |
| Juvenile | 🐱 | 🤒 | ✨ |
| Adult | 😺 | 🤒 | ✨ |
| Legendary | 🦁 | 🤒 | ✨ |

### Garden

| Stage | Base | Sick overlay | Recovering overlay |
|---|---|---|---|
| Seed | 🌱 | 🍂 | ✨ |
| Sprout | 🌿 | 🍂 | ✨ |
| Bush | 🌳 | 🍂 | ✨ |
| Bloom | 🌸 | 🍂 | ✨ |
| Paradise | 🌺 | 🍂 | ✨ |

Sick state also applies a grey desaturation tint to the entire character via `.colorMultiply(.gray)`.

---

## Placement in the App

### Today tab
`CompanionCardView` is inserted above the habit list inside `TodayView`. It is always visible — not collapsible in v1.

### macOS menu bar popover
`CompanionMenuBarView` appears in the popover header between the date line and the habit list. (Menu bar popover is planned for Plan 3; this spec defines what the companion component looks like there.)

### Settings tab
A new "Companion" section in `SettingsView` contains `CompanionSettingsView` for type selection.

---

## App Initialization

On first launch, if no `Companion` record exists in SwiftData, one is created automatically with:
- `type = .pet`
- `xp = 0`
- `accessoriesUnlocked = []`

No onboarding screen. The companion just appears, ready to be fed.

---

## Out of Scope (v1)

- Custom pet names
- Animated sprite sheets (emoji + SwiftUI animations only)
- Pet-to-pet social interactions
- Pet death permadeath (sick is the lowest state — the companion can always be revived)
- Companion-specific push notifications ("Your pet is starving! 😰")
- Apple Watch companion glance
