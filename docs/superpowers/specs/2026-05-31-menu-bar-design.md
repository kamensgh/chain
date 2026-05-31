# Chain macOS Menu Bar — Design Spec
**Date:** 2026-05-31
**Status:** Approved

---

## Overview

A `MenuBarExtra` scene lives alongside the main `WindowGroup` in `ChainApp`. It shows the companion emoji as the always-visible menu bar icon and opens a 280 pt popover when clicked. The popover lets users see today's habit status and check off habits without switching to the main app window.

macOS only — the entire feature is wrapped in `#if os(macOS)`.

---

## Menu Bar Icon

`MenuBarIconView` is the label for the `MenuBarExtra`. It queries the `Companion` and `Habit` models directly and renders:

- The companion emoji for the current stage × health state (e.g. 🥚 sick → greyed, 🦁 fed → full color)
- An 8 pt colored health dot beneath the emoji

Health dot colors match `CompanionMenuBarView`:

| NeedState | Color |
|---|---|
| `fed` | `.green` |
| `peckish` | `.green.opacity(0.6)` |
| `hungry` | `.yellow` |
| `starving` | `.orange` |
| `sick` | `.gray` |

The emoji is rendered at ~18 pt to fit comfortably in the macOS menu bar height. The popover header uses the larger `CompanionMenuBarView` (28 pt).

The emoji uses `.colorMultiply(.gray)` when overall state is `.sick`, same as the in-app card.

---

## Popover Content

`MenuBarPopoverView` is the popover body. Fixed width: 280 pt. Scrollable if the habit list overflows.

### Layout (top to bottom)

1. **Date header** — `Text` showing today's full date (e.g. "Saturday, May 31"). `.font(.caption)`, `.foregroundStyle(.secondary)`.

2. **Companion row** — reuses `CompanionMenuBarView` (animated emoji + health dot, already built).

3. **Divider**

4. **Habit list** — `ForEach` of all habits sorted by creation order. Each row is `MenuBarHabitRowView`.

5. **Divider**

6. **Footer** — "Open Chain" button. Uses `@Environment(\.openWindow)` with `id: "main"` (the `WindowGroup` is given this ID in `ChainApp`) to bring the main window to the front. Also calls `NSApp.activate(ignoringOtherApps: true)` so the app comes to front even if it's behind other windows.

---

## MenuBarHabitRowView

Compact row — no streak badge, no status label, no source label.

```
[ emoji ]  Habit name                    [ ○ / ✓ ]
```

- Left: habit emoji in a small circle (32 pt), habit name `.subheadline`
- Right: `checkmark.circle.fill` (accentColor) if verified; plain `circle` button if not
- Tapping the button calls the shared `verifyHabit(_:context:)` helper

---

## Shared Verify Helper

The verify + XP logic currently lives inline in `TodayView`. To avoid duplication, extract it into:

```swift
// Chain/Connectors/HabitVerifier.swift
@MainActor
enum HabitVerifier {
    static func verify(_ habit: Habit, context: ModelContext, companions: [Companion])
}
```

Both `TodayView` and `MenuBarHabitRowView` call this. `TodayView` is updated to use it; the inline `verify(habit:)` and `applyDailyXP()` methods are replaced.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Views/MenuBar/MenuBarIconView.swift` | Menu bar label: companion emoji + health dot |
| `Chain/Views/MenuBar/MenuBarPopoverView.swift` | Popover: date + companion + habit list + footer |
| `Chain/Views/MenuBar/MenuBarHabitRowView.swift` | Compact habit row with verify button |
| `Chain/Connectors/HabitVerifier.swift` | Shared verify + XP helper used by TodayView and MenuBarHabitRowView |

### Modified files

| File | Change |
|---|---|
| `Chain/ChainApp.swift` | Add `MenuBarExtra` scene (macOS only) with `.menuBarExtraStyle(.window)` and `.modelContainer(container)`; add `id: "main"` to `WindowGroup` |
| `Chain/Views/Today/TodayView.swift` | Replace inline `verify(habit:)` + `applyDailyXP()` with `HabitVerifier.verify(_:context:companions:)` |
| `Package.swift` | Add `"Connectors/HabitVerifier.swift"` to the SPM `exclude` list (imports SwiftData) |

### No changes to

- Domain layer (`CompanionEngine`, `StreakCalculator`, `HabitScheduler`)
- SwiftData models
- iOS code paths

---

## ModelContainer sharing

`MenuBarExtra` receives the same `ModelContainer` instance as the `WindowGroup` via `.modelContainer(container)`. SwiftData propagates changes across both scenes automatically — checking a habit in the popover immediately reflects in the main window.

---

## Out of Scope (v1)

- Connector auto-verify triggered from the menu bar (HealthKit / MCP calls happen only in TodayView)
- Notification badge on the menu bar icon
- Clicking a habit row to deep-link into the main window's detail view
- iOS / iPadOS (no menu bar on those platforms)
