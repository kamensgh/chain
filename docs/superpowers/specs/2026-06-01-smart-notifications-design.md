# Chain Smart Notifications — Design Spec
**Date:** 2026-06-01
**Status:** Approved

---

## Overview

Provide three user-configurable smart notifications: an end-of-day nudge (reminds user to check in), a streak-at-risk alert (fires later in the evening if any habit is still unverified), and a weekly summary (every Sunday). Notifications are scheduled around midnight-as-end-of-day; if all habits are already verified when the scheduler runs, pending nudge/at-risk notifications are cancelled automatically.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Connectors/SmartNotificationScheduler.swift` | Schedules and cancels the three smart notification types; excluded from SPM |

### Modified files

| File | Change |
|---|---|
| `Chain/Views/Settings/SettingsView.swift` | Add notification section with toggles + time pickers |
| `Chain/Views/Today/TodayView.swift` | Call `rescheduleForToday` on `.task`, after verify-all, and after each manual verify |
| `Package.swift` | Exclude `"Connectors/SmartNotificationScheduler.swift"` from SPM |

### No changes to

- SwiftData models
- `NotificationScheduler.swift` (milestone notifications unchanged)
- `ConnectorService.swift`

---

## SmartNotificationScheduler

`Chain/Connectors/SmartNotificationScheduler.swift`

### Notification identifiers

```swift
static let nudgeID   = "smart-nudge-today"
static let atRiskID  = "smart-at-risk-today"
static let weeklyID  = "smart-weekly-summary"
```

Stable identifiers allow re-scheduling to replace any previously-scheduled notification of the same type.

### rescheduleForToday

```swift
static func rescheduleForToday(habits: [Habit]) async {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized else { return }

    let allVerified = habits.allSatisfy { habit in
        let periodStart = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        return habit.entries.first { $0.periodStart == periodStart }?.status == .verified
    }

    // Cancel nudge and at-risk if all habits done
    if allVerified {
        center.removePendingNotificationRequests(withIdentifiers: [nudgeID, atRiskID])
    } else {
        if UserDefaults.standard.bool(forKey: "nudgeEnabled") {
            await schedule(id: nudgeID,
                           title: "Don't forget your habits today! 🔥",
                           body: "Keep your streak alive — check in before midnight.",
                           hour: UserDefaults.standard.integer(forKey: "nudgeHour"),
                           minute: UserDefaults.standard.integer(forKey: "nudgeMinute"))
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [nudgeID])
        }

        if UserDefaults.standard.bool(forKey: "atRiskEnabled") {
            await schedule(id: atRiskID,
                           title: "Some streaks are at risk — check in before midnight! ⚠️",
                           body: "Don't break the chain.",
                           hour: UserDefaults.standard.integer(forKey: "atRiskHour"),
                           minute: UserDefaults.standard.integer(forKey: "atRiskMinute"))
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [atRiskID])
        }
    }

    // Weekly summary always governed only by its toggle
    if UserDefaults.standard.bool(forKey: "weeklyEnabled") {
        await scheduleWeekly(id: weeklyID,
                             title: "How did your habits go this week? 📊",
                             body: "Tap to review your progress.",
                             hour: UserDefaults.standard.integer(forKey: "weeklyHour"),
                             minute: UserDefaults.standard.integer(forKey: "weeklyMinute"))
    } else {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyID])
    }
}
```

Content strings are generic (time-invariant) because they are set at scheduling time, not at delivery time.

### schedule (daily)

```swift
private static func schedule(id: String, title: String, body: String, hour: Int, minute: Int) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    try? await UNUserNotificationCenter.current().add(request)
}
```

`repeats: false` — the scheduler is called each day via TodayView's `.task` modifier, which re-registers the notification for the current day.

### scheduleWeekly (Sunday)

```swift
private static func scheduleWeekly(id: String, title: String, body: String, hour: Int, minute: Int) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    var components = DateComponents()
    components.weekday = 1   // Sunday
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    try? await UNUserNotificationCenter.current().add(request)
}
```

`repeats: true` so the weekly summary fires every Sunday without requiring daily re-scheduling.

---

## UserDefaults keys and defaults

| Key | Type | Default |
|---|---|---|
| `nudgeEnabled` | Bool | `true` |
| `nudgeHour` | Int | `21` (9 PM) |
| `nudgeMinute` | Int | `0` |
| `atRiskEnabled` | Bool | `true` |
| `atRiskHour` | Int | `22` (10 PM) |
| `atRiskMinute` | Int | `0` |
| `weeklyEnabled` | Bool | `true` |
| `weeklyHour` | Int | `20` (8 PM) |
| `weeklyMinute` | Int | `0` |

Defaults are registered via `UserDefaults.standard.register(defaults:)` at app startup in `ChainApp.init()`.

---

## TodayView changes

Three call sites in `TodayView`:

```swift
.task {
    await SmartNotificationScheduler.rescheduleForToday(habits: habits)
}
```

After `verifyAll()`:
```swift
Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
```

After each manual verify tap — add the reschedule call inside the `onVerify` closure that `TodayView` passes to `HabitRowView`:
```swift
// In TodayView, when constructing HabitRowView:
HabitRowView(habit: habit) {
    HabitVerifier.verify(habit: habit, context: modelContext)
    Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
}
```

`TodayView` already has `@Query var habits: [Habit]` so no new query is needed.

---

## Settings UI changes

`Chain/Views/Settings/SettingsView.swift`

Add a **Notifications** section below existing settings. The section is only shown when `UNUserNotificationCenter` authorization status is `.authorized`; if not authorized, show a single "Enable Notifications" button that calls `requestAuthorization`.

```swift
Section("Notifications") {
    NotificationRowView(
        label: "End-of-day nudge",
        enabledKey: "nudgeEnabled", enabledDefault: true,
        hourKey: "nudgeHour", hourDefault: 21,
        minuteKey: "nudgeMinute", minuteDefault: 0,
        habits: habits
    )
    NotificationRowView(
        label: "Streak at risk",
        enabledKey: "atRiskEnabled", enabledDefault: true,
        hourKey: "atRiskHour", hourDefault: 22,
        minuteKey: "atRiskMinute", minuteDefault: 0,
        habits: habits
    )
    NotificationRowView(
        label: "Weekly summary",
        enabledKey: "weeklyEnabled", enabledDefault: true,
        hourKey: "weeklyHour", hourDefault: 20,
        minuteKey: "weeklyMinute", minuteDefault: 0,
        habits: habits
    )
}
```

`SettingsView` adds `@Query var habits: [Habit]` to feed the reschedule call from within each row.

### NotificationRowView

A private helper view defined in `SettingsView.swift`:

```swift
private struct NotificationRowView: View {
    let label: String
    let enabledKey: String; let enabledDefault: Bool
    let hourKey: String; let hourDefault: Int
    let minuteKey: String; let minuteDefault: Int
    let habits: [Habit]

    @AppStorage var enabled: Bool
    @AppStorage var hour: Int
    @AppStorage var minute: Int

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour = comps.hour ?? hourDefault
                minute = comps.minute ?? minuteDefault
            }
        )
    }

    var body: some View {
        Toggle(label, isOn: $enabled)
            .onChange(of: enabled) { _, _ in
                Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
            }
        if enabled {
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .onChange(of: timeBinding.wrappedValue) { _, _ in
                    Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
                }
        }
    }
}
```

The `@AppStorage` property wrappers in `NotificationRowView` are initialized in `init` since their keys come from parameters.

---

## Out of Scope (v1)

- Per-habit notification times
- "Quiet hours" or Do Not Disturb integration
- Actionable notification buttons (Mark Done from notification)
- Notification history or inbox
- Android / web push

---

## Tests

`SmartNotificationScheduler` imports `UserNotifications` (not available headless) — excluded from SPM. No SPM tests for this component. Existing 68 tests must remain passing.
