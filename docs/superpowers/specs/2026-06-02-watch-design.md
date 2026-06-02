# Chain Apple Watch App — Design Spec
**Date:** 2026-06-02
**Status:** Approved

---

## Overview

A native watchOS companion app for Chain. Users see today's habits on their wrist and tap to verify them without opening the iPhone app. A circular Watch face complication shows daily progress at a glance.

---

## Platform targets

| Platform | Deployment target |
|---|---|
| iOS | 18.0 (bumped from 17.0) |
| macOS | 14.0 (unchanged) |
| watchOS | 11.0 (new) |

---

## Architecture

### New xcodegen targets

**`ChainWatch`** — watchOS 11 application. Single-tab Today view. Sources `ChainWatch/` plus `Chain/Models` and `Chain/Domain` directly (same pattern as `ChainWidget`). Embeds `ChainWatchWidget`. Depends on `WatchConnectivity.framework`.

**`ChainWatchWidget`** — WidgetKit extension embedded inside `ChainWatch`. Provides the `.accessoryCircular` complication. Sources `ChainWatchWidget/` plus `Chain/Models` and `Chain/Domain`. Reads from `UserDefaults` populated by the Watch app's `WatchSession`.

### Data sync — WatchConnectivity

Chain uses `WCSession` for all iPhone ↔ Watch communication. No shared App Group (watchOS cannot access the iOS App Group container).

**iPhone → Watch (snapshot):**
- `WCSession.default.updateApplicationContext(payload)` called on app launch and after every habit verify
- Payload is a `[String: Any]` dict with an array of habit summaries: `id` (UUID string), `name`, `emoji`, `isVerifiedToday` (Bool), `currentStreak` (Int)
- `applicationContext` is coalescing — only the latest snapshot is delivered, which is correct since only current state matters

**Watch → iPhone (verify action):**
- `WCSession.default.sendMessage(["action": "verify", "habitID": uuidString], replyHandler: nil)`
- If iPhone is unreachable, falls back to `transferUserInfo(["action": "verify", "habitID": uuidString])` — guaranteed delivery when the session reconnects
- iPhone receives the message, writes a `HabitEntry` to SwiftData (`.verified`, `.manual`), then calls `WidgetCenter.shared.reloadAllTimelines()` and sends a fresh `applicationContext` snapshot back

**Complication data:**
- When `WatchSession` receives a new snapshot, it writes `verifiedCount` and `totalCount` to `UserDefaults.standard` and calls `WidgetCenter.shared.reloadAllTimelines()`
- `WatchWidgetProvider` reads those two values from `UserDefaults.standard` — no suite name needed because `ChainWatchWidget` is embedded inside `ChainWatch` and shares the same app container

---

## File map

| File | Action | Purpose |
|---|---|---|
| `project.yml` | Modify | Bump iOS to 18, add watchOS 11, add ChainWatch + ChainWatchWidget targets |
| `Chain/ChainApp.swift` | Modify | Activate `WCSession` on launch |
| `Chain/WatchSession.swift` | Create | iPhone-side `WCSessionDelegate` — sends snapshots, receives verify messages. Defines `WatchPayload` struct (Codable snapshot) |
| `Chain/Views/Today/TodayView.swift` | Modify | Send WatchConnectivity snapshot after every verify |
| `ChainWatch/ChainWatchApp.swift` | Create | `@main` Watch app — activates `WCSession` |
| `ChainWatch/WatchSession.swift` | Create | Watch-side `WCSessionDelegate` — receives snapshots, sends verify messages, writes UserDefaults |
| `ChainWatch/WatchHabitStore.swift` | Create | `@Observable` store backed by `UserDefaults`, drives Watch UI |
| `ChainWatch/Views/TodayWatchView.swift` | Create | Main scroll view — habit list with verify buttons |
| `ChainWatch/Views/HabitRowWatchView.swift` | Create | Individual habit row: emoji + name + streak badge + verify ring button |
| `ChainWatchWidget/WatchWidgetProvider.swift` | Create | WidgetKit `TimelineProvider` reading `verifiedCount`/`totalCount` from UserDefaults |
| `ChainWatchWidget/WatchComplicationView.swift` | Create | `.accessoryCircular` progress ring — matches lock screen widget style |
| `ChainWatchWidget/ChainWatchWidgetBundle.swift` | Create | `@main` WidgetBundle for the complication extension |

---

## Watch UI

### Today view (single screen)

`NavigationStack` wrapping a `ScrollView` of `HabitRowWatchView` items. Digital Crown scrolls through habits.

**Header:** `⛓️ Today` title + `verifiedCount / totalCount` count in accent color.

**Habit row:** Emoji + habit name (one line, truncated) + streak badge (`🔥 Nd` in orange if streak > 0). Trailing: a filled green checkmark (`checkmark.circle.fill`) if verified, otherwise a tappable empty circle (`circle`) in accent color. Tapping the circle sends a verify action and optimistically updates the local store.

**Empty state:** When `WatchHabitStore.habits` is empty (no snapshot received yet), show a full-screen message: "Open Chain on iPhone to sync your habits."

**Last synced:** Small secondary text at the bottom of the list showing the snapshot timestamp (e.g. "Synced 2 min ago").

### Complication

`.accessoryCircular` — a `Circle().trim` progress ring identical in design to `LockScreenWidgetView`'s circular case:
- Track: `Circle().stroke(secondary.opacity(0.2), lineWidth: 5)`
- Progress arc: green when `verifiedCount == totalCount`, accent color otherwise
- Center text: `"\(verifiedCount)/\(totalCount)"`
- When all done: center shows `✓` in green

---

## Error handling

| Scenario | Behaviour |
|---|---|
| No snapshot received yet | Empty-state message: "Open Chain on iPhone to sync" |
| iPhone unreachable on verify | `sendMessage` fails silently; `transferUserInfo` queues the verify for guaranteed delivery on reconnect |
| Snapshot parse failure | Silently ignore malformed payload; keep last known state |

---

## Testing

WatchConnectivity itself requires paired hardware and is not unit-tested. The following are unit-testable and will have SPM tests:

- `WatchPayload` encode/decode (snapshot serialisation round-trip)
- `WatchHabitStore` population from a decoded payload

All domain logic (`StreakCalculator`, `HabitScheduler`) is already covered by the existing 68 SPM tests and requires no changes.

---

## project.yml changes (summary)

```yaml
options:
  deploymentTarget:
    iOS: "18.0"        # bumped
    macOS: "14.0"
    watchOS: "11.0"    # new

targets:
  Chain:
    dependencies:
      # existing deps preserved (ChainWidget embed stays)
      - target: ChainWatch
        embed: true
        platforms: [watchOS]   # new
      - sdk: WatchConnectivity.framework
        platforms: [iOS]       # new

  ChainWatch:
    type: application
    platform: watchOS
    sources:
      - path: ChainWatch
      - path: Chain/Models
      - path: Chain/Domain
    dependencies:
      - target: ChainWatchWidget
        embed: true
      - sdk: WatchConnectivity.framework
    settings:
      base:
        SWIFT_VERSION: "5.9"
        PRODUCT_BUNDLE_IDENTIFIER: com.chain.Chain.watch

  ChainWatchWidget:
    type: app-extension
    platform: watchOS
    sources:
      - path: ChainWatchWidget
      - path: Chain/Models
      - path: Chain/Domain
    settings:
      base:
        SWIFT_VERSION: "5.9"
        PRODUCT_BUNDLE_IDENTIFIER: com.chain.Chain.watch.widget
```
