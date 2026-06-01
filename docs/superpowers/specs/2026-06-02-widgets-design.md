# Chain Widgets — Design Spec
**Date:** 2026-06-02
**Status:** Approved

---

## Overview

WidgetKit extension adding three widget families to Chain: a small home-screen overview ring, an interactive medium habit list, and lock-screen circular/inline accessories. Widgets share the same SwiftData store as the main app via an App Group. The medium widget supports inline habit verification without opening the app (iOS 17 `AppIntents`).

---

## Architecture

### New target: `ChainWidget`

A `widgetExtension` target added to `project.yml`. Shares the App Group `group.com.chain.app` with the main app via its own `ChainWidget.entitlements`.

### App Group shared store

`ModelContainerFactory.make()` gains an `inAppGroup: Bool` parameter (default `false`). When `true`, the `ModelConfiguration` uses `groupContainer: .identifier("group.com.chain.app")` so the SwiftData store lives in the shared App Group container and both targets read/write the same data.

- Main app (`ChainApp.swift`): passes `inAppGroup: true`
- Widget extension (`Provider.swift`): passes `inAppGroup: true`

### New files

| File | Purpose |
|---|---|
| `ChainWidget/ChainWidgetBundle.swift` | `@main` entry — registers all three widget kinds |
| `ChainWidget/Provider.swift` | `TimelineProvider` — loads habits, builds timeline entries |
| `ChainWidget/WidgetEntry.swift` | `TimelineEntry` — snapshot of habits for a given date |
| `ChainWidget/VerifyHabitIntent.swift` | `AppIntent` — marks one habit verified, reloads timelines |
| `ChainWidget/SmallWidgetView.swift` | Progress ring + best active streak count |
| `ChainWidget/MediumWidgetView.swift` | Habit list with per-row verify buttons |
| `ChainWidget/LockScreenWidgetView.swift` | `accessoryCircular` + `accessoryInline` views |
| `ChainWidget/ChainWidget.entitlements` | App Group entitlement for widget target |

### Modified files

| File | Change |
|---|---|
| `Chain/Persistence/ModelContainerFactory.swift` | Add `inAppGroup: Bool = false` param; use `groupContainer` when true |
| `Chain/ChainApp.swift` | Pass `inAppGroup: true` to `ModelContainerFactory.make()` |
| `Chain/Chain.entitlements` | Add `com.apple.security.application-groups` with `group.com.chain.app` |
| `Chain/Views/Today/TodayView.swift` | Call `WidgetCenter.shared.reloadAllTimelines()` after verify |
| `project.yml` | Add `ChainWidget` extension target with entitlements + App Group |

---

## Widget Kinds

### 1. `ChainSmallWidget` — `.systemSmall`

**Purpose:** Glanceable daily progress. Tap deep-links to Today view.

**Content:**
- Circular progress ring showing `verified / total` habits for today (accent color → green when complete)
- `X/N` count centred in the ring
- "Today" label below ring
- Best active streak (`🔥 Nd best streak`) below label — the highest `StreakCalculator.current()` value across all habits

**States:**
- 0 habits: ring empty, count `0/N`, streak label shown
- Partial: ring partially filled (accent purple)
- All done: ring full green, label reads "All done ✓"

**Interaction:** `.widgetURL` deep-links to the app's Today tab. No verify button (not enough space).

---

### 2. `ChainMediumWidget` — `.systemMedium`

**Purpose:** Interactive daily checklist. Mark habits done without opening the app.

**Content:**
- Header row: `⛓️ Today` title + `X / N` count (accent color)
- Up to 4 habit rows (truncated if more):
  - Verified row: emoji + name + ✅ checkmark
  - Unverified row: emoji + name + `Mark done` button (accent filled, fires `VerifyHabitIntent`)
- Verified rows have no button — tapping the row deep-links to the app

**Interaction:**
- `Mark done` button → `VerifyHabitIntent(habitID:)` → inserts `HabitEntry`, saves, calls `WidgetCenter.shared.reloadAllTimelines()`
- Tapping elsewhere → `.widgetURL` deep-link to Today view

**Truncation:** If the user has more than 4 habits, show the first 4 sorted by `createdAt` ascending (oldest habits first). A `+N more` label is shown if habits are truncated.

---

### 3. `ChainLockScreenWidget` — `.accessoryCircular` + `.accessoryInline`

**Purpose:** At-a-glance streak and progress directly on the lock screen.

**accessoryCircular:**
- 🔥 emoji + best active streak count (largest streak across all habits today)
- Falls back to "0" if no active streaks

**accessoryInline:**
- `⛓️ X / N habits done` text
- Updates throughout the day as habits are verified

**Interaction:** Both are read-only — tapping opens the app. Lock screen widgets cannot host interactive buttons.

Both are registered as a single `ChainLockScreenWidget` using `@Environment(\.widgetFamily)` to branch on `.accessoryCircular` vs `.accessoryInline`.

---

## Data Flow

### TimelineProvider

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
    // 1. Open shared ModelContainer
    // 2. Fetch all Habit objects with entries
    // 3. For each habit: compute isDue (HabitScheduler), currentStreak (StreakCalculator)
    // 4. Build WidgetEntry with [HabitSummary] snapshot
    // 5. Schedule next refresh at midnight (habits reset)
    let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
    let timeline = Timeline(entries: [entry], policy: .after(midnight))
    completion(timeline)
}
```

`WidgetEntry` contains:
```swift
struct WidgetEntry: TimelineEntry {
    let date: Date
    let habits: [HabitSummary]  // name, emoji, id, isVerifiedToday, currentStreak
    let bestStreak: Int
    let verifiedCount: Int
    let totalCount: Int
}
```

### VerifyHabitIntent

```swift
struct VerifyHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Verify Habit"
    @Parameter(title: "Habit ID") var habitID: String

    func perform() async throws -> some IntentResult {
        let container = try ModelContainerFactory.make(inAppGroup: true)
        let context = ModelContext(container)
        // fetch habit by id, insert HabitEntry(.verified), save
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

### App-side widget reload

In `TodayView`, after any verify action (manual tap, auto-verify), add:
```swift
WidgetCenter.shared.reloadAllTimelines()
```

---

## project.yml additions

```yaml
ChainWidget:
  type: app-extension
  platform: iOS
  sources:
    - path: ChainWidget
  dependencies:
    - target: Chain_iOS
      embed: false
  settings:
    base:
      SWIFT_VERSION: "5.9"
      CODE_SIGN_ENTITLEMENTS: ChainWidget/ChainWidget.entitlements
      PRODUCT_BUNDLE_IDENTIFIER: com.chain.app.widget
  info:
    path: ChainWidget/Info.plist
    properties:
      NSExtension:
        NSExtensionPointIdentifier: com.apple.widgetkit-extension
```

Also add `ChainWidget` as an embedded dependency of the `Chain` target in `project.yml`:

```yaml
Chain:
  # existing config...
  dependencies:
    - target: ChainWidget
      embed: true
```

---

## App Group Entitlements

**`Chain/Chain.entitlements`** — add:
```xml
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.chain.app</string>
</array>
```

**`ChainWidget/ChainWidget.entitlements`** — new file:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.chain.app</string>
  </array>
</dict>
</plist>
```

---

## Tests

All new files are SwiftUI views or WidgetKit types — excluded from the SPM `ChainDomain` target automatically. The existing 68 SPM tests must remain passing. Manual verification: add widget to home screen, verify a habit from the widget, confirm Today view reflects the change.

---

## Out of Scope (v1)

- macOS widgets (macOS menu bar already serves this role)
- Widget configuration UI (user picking which habit for a custom view)
- Large home-screen widget (`systemLarge`)
- `accessoryRectangular` lock screen widget
- Watch complications
