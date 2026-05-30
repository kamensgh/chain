# Chain — Design Spec
**Date:** 2026-05-25
**Status:** Approved

---

## Overview

Chain is a native Apple habit streak app (macOS + iOS) that helps people pick up habits and stick to them. Its defining feature is the ability to verify habit completion automatically by connecting to real apps — via MCP servers, native Apple APIs, or screenshot proof — instead of relying on manual check-ins alone. The visual style is playful and bubbly, using system accent colors and native materials throughout.

---

## Platform & Tech Stack

| Concern | Decision |
|---|---|
| Platform | macOS + iOS, Apple ecosystem only |
| UI framework | SwiftUI (shared codebase, platform-adaptive) |
| Data persistence | SwiftData |
| Mac↔iPhone sync | CloudKit (automatic, no account required) |
| Notifications | UserNotifications framework (local only) |
| Backend | None — free, offline-first, zero running costs |
| Monetization | Free |

---

## Architecture

Four layers:

1. **UI Layer** — SwiftUI views shared across Mac and iPhone. iPhone uses a tab bar; Mac uses a sidebar + menu bar popover. Both adapt to the user's system accent color via `Color.accentColor` and use `.ultraThinMaterial` for translucent surfaces.

2. **Domain Layer** — Habit logic, streak calculation, goal evaluation. Streaks are computed on the fly from `HabitEntry` history — never stored — so they're always accurate and can handle retroactive edits.

3. **Connector Layer** — Pluggable system for verifying habit completion. Each connector implements `HabitConnector`, a Swift protocol with a single `verify(habit:) async → VerificationResult` method. Built-in connectors ship with the app; custom MCP connectors are added via user configuration without an app update.

4. **Data Layer** — SwiftData models synced to CloudKit.

---

## Data Model

```swift
// Core models (SwiftData)

Habit
  id: UUID
  name: String
  emoji: String
  color: String                  // per-habit tint (optional, falls back to accent)
  frequency: Frequency           // .daily | .weekly | .monthly
  goal: GoalConfig               // { targetValue: Double, unit: GoalUnit }
                                 // GoalUnit: .steps | .minutes | .boolean | .custom(label)
  connector: ConnectorConfig?    // type + non-sensitive metadata only (e.g. endpoint URL, username)
                                 // credentials (API keys, OAuth tokens) stored in Keychain, keyed by habit.id
  reminderTime: Date?
  gracePeriodEnabled: Bool       // optional 1-day streak freeze
  createdAt: Date

HabitEntry                       // one record per period per habit
  id: UUID
  habitId: UUID
  periodStart: Date              // start of day/week/month
  status: EntryStatus            // .pending | .verified | .skipped
  verificationMethod: VerifMethod // .auto | .screenshot | .manual
  value: Double?                 // e.g. 8432 steps
  screenshotPath: String?
  verifiedAt: Date?

// Streak is computed, not stored
struct Streak {
  current: Int
  longest: Int
  lastCompletedDate: Date?
}
```

**Streak rules:**
- Daily habit: breaks if no verified entry exists by midnight
- Weekly habit: must have a verified entry within the current Mon–Sun window
- Monthly habit: must have a verified entry within the current calendar month
- Grace period (opt-in per habit): one missed day doesn't break the streak — the next verified day repairs it

---

## Connector System

Each connector implements:

```swift
protocol HabitConnector {
  func verify(habit: Habit) async throws -> VerificationResult
}

struct VerificationResult {
  let status: EntryStatus
  let value: Double?
  let source: String            // e.g. "Apple Health · 8,432 steps"
}
```

### Built-in Connectors

| Connector | Integration | What it tracks |
|---|---|---|
| Apple Health | HealthKit (native, no setup) | Steps, workouts, sleep, water, mindfulness, calories |
| GitHub | GitHub MCP server (OAuth) | Commits, PRs, code reviews |
| Notion | Notion MCP server (API key) | Pages created/edited, database entries |
| Todoist / Linear | Their MCP servers | Tasks completed, issues closed |
| Screen Time | FamilyControls / DeviceActivity API | App usage limits, downtime windows |
| Strava | Strava MCP / OAuth | Runs, rides, swims |

### Connector Refresh Timing

Connectors poll in three situations:
1. **App foreground / popover open** — all connectors for today's habits run immediately
2. **Background App Refresh** — iOS/macOS calls the app periodically; connectors re-poll and fire a local notification if a habit auto-completes while the app is closed
3. **Manual pull-to-refresh** — user can force a re-check from the Today screen

HealthKit connectors use `HKObserverQuery` for real-time push updates (no polling needed). MCP/API connectors use simple async HTTP calls at the above trigger points.

### Universal Fallbacks (always available)

| Method | How it works |
|---|---|
| Screenshot proof | User submits a photo from Photos library or camera; stored locally with the HabitEntry |
| Manual check-in | One-tap mark as done — no integration needed |
| Custom MCP server | Advanced users configure any MCP-compatible endpoint |

---

## Navigation Structure

### iPhone — Tab Bar
| Tab | Purpose |
|---|---|
| 🏠 Today | Daily habits to complete, progress bar, streak counts, one-tap verify or screenshot submit |
| 🎯 Habits | Full habit list; add, edit, delete; configure connectors and reminders |
| 📊 Stats | Streak calendar (GitHub-style contribution graph), longest streak, weekly/monthly completion rate |
| ⚙️ Settings | Reminder times, connected apps, MCP server configuration, notification preferences |

### macOS — Sidebar + Menu Bar

Same 4 sections in a sidebar. Additionally, Chain lives in the **macOS menu bar** as a ⛓️ icon. Clicking it opens a translucent popover (`.ultraThinMaterial`, frosted glass) showing:
- Today's date and habits-done count
- Each habit with status, connector source label, and streak flame count
- Progress bar
- "Open Chain" button → full window
- "+ Add Habit" shortcut

The menu bar popover is the primary macOS touch point — most users will never need to open the full window on a day-to-day basis.

---

## Notifications & Reminders

All notifications are local (`UserNotifications`). No server required.

| Notification | Trigger | Content |
|---|---|---|
| Per-habit reminder | Time set per habit | "Time to [habit name]! 🔥 Keep your streak going" |
| End-of-day nudge | 9pm if any habits pending (adjustable) | "You've got 2 habits left today 🔥" |
| Streak at-risk warning | 10pm if habit unverified (adjustable) | "Your 14-day coding streak is at risk!" |
| Streak milestone | On verification at 7, 14, 30, 60, 100 days | "🎉 21-day streak! You're on fire!" + in-app confetti |
| Weekly summary | Sunday evening | "You completed 18/21 habits this week 🌟" |

---

## Visual Design

- **Style:** Playful & bubbly — rounded corners, bouncy animations, emoji-first habit icons, celebratory confetti on milestones
- **Color:** `Color.accentColor` throughout — automatically matches the user's system accent (blue, pink, orange, green, purple, red)
- **Materials:** `.ultraThinMaterial` for the menu bar popover and any sheet/overlay surfaces — native macOS/iOS frosted glass vibrancy
- **Typography:** SF Pro (system font) — no custom fonts needed
- **Dark/light mode:** Fully supported automatically via SwiftUI semantic colors

---

## Key User Flows

### Add a Habit
1. Tap "+ Add Habit" (Today tab or menu bar shortcut)
2. Pick emoji + name
3. Set frequency: daily / weekly / monthly
4. Set goal: boolean done, steps count, minutes, or custom value
5. Choose connector: pick from list or skip for manual
6. Set reminder time (optional)
7. Enable grace period (optional)
8. Save → habit appears in Today

### Verify a Habit
**Auto (MCP/HealthKit):** Connector runs in background; habit auto-marks verified when goal is met. User sees a ✅ appear with the data source label.

**Screenshot:** Tap habit → "Add Screenshot" → pick from Photos or camera → stored with the entry.

**Manual:** Tap the habit row → confirm → marked done instantly.

### Break & Repair a Streak
- Missed day with grace period off → streak resets to 0
- Missed day with grace period on → streak frozen; next verified day repairs it (streak count continues)

---

## Out of Scope (v1)

- Social features (friends, shared challenges, reactions)
- Backend / user accounts
- Android
- Paid features / subscriptions
- AI-generated habit suggestions
- Apple Watch app (post-v1)
- Widgets (post-v1, good second milestone)
