# Chain Stats Screen — Design Spec
**Date:** 2026-05-31
**Status:** Approved

---

## Overview

Replace the placeholder `StatsView` with a fully-functional statistics screen. A `.segmented` `Picker` at the top lets the user switch between three views: Streaks, Summary, and Calendar. All three share the same 30-day rolling window.

Works identically on macOS and iOS — no platform-specific code needed.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Domain/StatsCalculator.swift` | Pure domain — computes periods in window + completion rate; testable in SPM |
| `Chain/Views/Stats/StreaksTabView.swift` | Per-habit streak rows (current, longest, 30-day rate) |
| `Chain/Views/Stats/SummaryTabView.swift` | Headline card + per-habit progress bars |
| `Chain/Views/Stats/CalendarTabView.swift` | 30-day grid per habit |

### Modified files

| File | Change |
|---|---|
| `Chain/Views/Stats/StatsView.swift` | Replace placeholder body with `Picker` + tab switcher |

### No changes to

- Domain layer (`StreakCalculator`, `HabitScheduler`, `CompanionEngine`)
- SwiftData models
- Any connector or menu bar code

---

## StatsCalculator

Located at `Chain/Domain/StatsCalculator.swift`. Pure `enum`, no imports beyond `Foundation`. Included in the SPM `ChainDomain` target (no exclusion needed since it has no SwiftData imports).

```swift
enum StatsCalculator {
    /// Returns all period-start dates that fall within the last `days` days.
    static func periodsInWindow(
        frequency: Frequency,
        days: Int = 30,
        today: Date = .now
    ) -> [Date]

    /// Returns the fraction of periods in the window that have a verified entry.
    /// Callers map habit.entries to [StreakEntry] before passing in.
    static func completionRate(
        entries: [StreakEntry],
        frequency: Frequency,
        days: Int = 30,
        today: Date = .now
    ) -> Double
}
```

`periodsInWindow` walks backwards from `today` by one calendar day at a time, collecting unique period-start dates until it has stepped back `days` days. Deduplication preserves weekly/monthly habits having fewer periods than `days`.

`completionRate` calls `periodsInWindow`, counts how many of those dates have a matching verified entry (`status == .verified`) in `entries`, and returns `Double(verified) / Double(total)` — or `0.0` if `total == 0`.

`StreakEntry` (already defined in `StreakCalculator.swift`) carries `periodStart: Date` and `status: EntryStatus` — exactly what's needed. Callers convert: `habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }`.

---

## StatsView (container)

`StatsTab` enum: `.streaks`, `.summary`, `.calendar`.

```swift
enum StatsTab: String, CaseIterable, Identifiable {
    case streaks = "Streaks"
    case summary = "Summary"
    case calendar = "Calendar"
    var id: String { rawValue }
}
```

`StatsView` holds `@State var selectedTab: StatsTab = .streaks` and renders:

1. `Picker("", selection: $selectedTab)` with `.pickerStyle(.segmented)` — padded top.
2. A `switch selectedTab` that shows the corresponding tab view.
3. `.navigationTitle("Stats")`.

No `@Query` in `StatsView` itself — each tab view owns its own query.

---

## StreaksTabView

`@Query(sort: \Habit.createdAt) var habits: [Habit]`

Scrollable `VStack`. Each row:

```
[ emoji circle 32pt ]  Habit name (.subheadline bold)
                        🔥 12  ·  ⭐ 24  ·  83%
```

- **Current streak**: `StreakCalculator.current(entries:frequency:today:gracePeriod:)` — maps `habit.entries` to `[StreakEntry]`.
- **Longest streak**: `StreakCalculator.longest(entries:frequency:)`.
- **30-day rate**: `StatsCalculator.completionRate(entries:frequency:)` where entries are mapped from `habit.entries` — formatted as `Int(rate * 100)%`.
- Emoji in a `.fill(Color.accentColor.opacity(0.15))` circle, 32 pt diameter.
- If `habits.isEmpty`, show `ContentUnavailableView("No habits yet", systemImage: "target")`.

---

## SummaryTabView

`@Query(sort: \Habit.createdAt) var habits: [Habit]`

Two sections:

### Headline card

Rounded rectangle card (`.fill(.secondary.opacity(0.1))`). Two stats side-by-side:

- **On track today**: count of habits with a verified entry for today's period, displayed as "X / Y".
- **30-day avg**: mean of `StatsCalculator.completionRate` across all habits, displayed as `Int(avg * 100)%`.

### Per-habit rows

`ForEach(habits)`. Each row:

```
[ emoji ]  Habit name            83%
           ████████░░░░░░░░░░░░
```

- Progress bar: `GeometryReader`-based `Capsule`, height 6 pt, `.accentColor` fill, `.secondary.opacity(0.2)` track.
- Percent label right-aligned, `.caption`, `.secondary`.
- Completion rate from `StatsCalculator.completionRate(entries:frequency:)` — entries mapped from `habit.entries`.

---

## CalendarTabView

`@Query(sort: \Habit.createdAt) var habits: [Habit]`

`ScrollView`. For each habit: a section header (emoji + name, `.subheadline bold`) followed by a 30-day grid.

### Grid layout

30 cells arranged as 5 rows × 6 columns (oldest cell top-left, newest bottom-right). Each cell is a 28×28 pt rounded rectangle (`cornerRadius: 6`):

| State | Color |
|---|---|
| Verified | `.accentColor` |
| Missed (period passed, not verified) | `.secondary.opacity(0.15)` |
| Future / not a period for this frequency | `.clear` (hidden) |

Cell determination:
1. Get all 30 period-start dates from `StatsCalculator.periodsInWindow(frequency:days:30)`.
2. Walk 30 calendar days back from today. For each day, check if it is a period-start for this habit's frequency. If yes, look up the entry; if no, render `.clear`.
3. Entry verified → accent; entry missing → faded gray.

Spacing between habit sections: 24 pt. Spacing between cells: 4 pt.

---

## Data flow

All three tab views use `@Query` to read habits, then access `habit.entries` via the SwiftData relationship. No extra queries. `StatsCalculator` and `StreakCalculator` are called pure-functionally — no stored state, no `@State` computed properties.

---

## Out of Scope (v1)

- Filtering by date range beyond 30 days
- Exporting stats as CSV / image
- Charts framework (Swift Charts) — dots and bars are sufficient
- Per-entry detail drill-down
- Notifications or reminders from the Stats screen
