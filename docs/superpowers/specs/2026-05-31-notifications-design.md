# Chain Notifications — Design Spec
**Date:** 2026-05-31
**Status:** Approved

---

## Overview

Wire up `UNUserNotificationCenter` reminders for habits. The `Habit` model already has `reminderTime: Date?` and `AddHabitView` already saves it. This feature schedules actual local notifications, handles permission, and keeps the pending notification set in sync as habits are created, edited, or deleted.

macOS and iOS both use `UNUserNotificationCenter` — no platform-specific branching needed in `NotificationScheduler`.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Connectors/NotificationScheduler.swift` | Static service: schedule, cancel, reschedule all, request authorization |

### Modified files

| File | Change |
|---|---|
| `Chain/Views/Habits/AddHabitView.swift` | Call `schedule`/`cancel` in `save()` via `Task { }` |
| `Chain/Views/Today/TodayView.swift` | Add `rescheduleAll` to `.task` alongside `verifyAll()` |
| `Chain/Views/Settings/SettingsView.swift` | Replace placeholder with live authorization status UI |
| `Package.swift` | Add `"Connectors/NotificationScheduler.swift"` to the SPM exclude list (imports `UserNotifications`) |

### No changes to

- `Habit` model — `reminderTime: Date?` already exists
- Domain layer, stats, menu bar, connector logic

---

## NotificationScheduler

`Chain/Connectors/NotificationScheduler.swift`

```swift
import UserNotifications
import Foundation

enum NotificationScheduler {

    @discardableResult
    static func requestAuthorization() async -> Bool

    static func schedule(for habit: Habit) async

    static func cancel(for habit: Habit)

    static func rescheduleAll(_ habits: [Habit]) async
}
```

### Notification identifier

`habit.id.uuidString` — one notification per habit, stable across edits.

### Notification content

- **Title**: `"\(habit.emoji) \(habit.name)"`
- **Body**: empty
- **Sound**: `.default`

### Trigger

`UNCalendarNotificationTrigger` constructed from `reminderTime`'s hour and minute components using `Calendar.current`. `repeats: true` — fires daily at that time.

```swift
var components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
```

### `requestAuthorization`

Calls `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`. Returns `true` if granted, `false` otherwise. Errors are swallowed (return `false`).

### `schedule(for:)`

1. If `habit.reminderTime == nil`, calls `cancel(for: habit)` and returns.
2. Builds a `UNMutableNotificationContent` + trigger as above.
3. Calls `UNUserNotificationCenter.current().add(request)`. Errors are swallowed.

### `cancel(for:)`

Calls `UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [habit.id.uuidString])`.

### `rescheduleAll`

1. Collects all habit UUIDs as strings.
2. Removes all pending notifications with those identifiers.
3. For each habit where `reminderTime != nil`, calls `schedule(for:)`.

---

## AddHabitView changes

In `save()`, add a `Task { }` block after `try? context.save()` and before `dismiss()`. The edit and create paths each have a local `h` in scope:

```swift
// Edit path
if let h = habit {
    // ... existing field updates ...
    h.reminderTime = reminderEnabled ? reminderTime : nil
    Task { await NotificationScheduler.schedule(for: h) }
} else {
    let h = Habit(name: trimmedName, emoji: emoji, frequency: frequency, goalConfig: goal)
    h.connectorType = connectorType
    h.gracePeriodEnabled = gracePeriodEnabled
    h.reminderTime = reminderEnabled ? reminderTime : nil
    context.insert(h)
    Task { await NotificationScheduler.schedule(for: h) }
}
try? context.save()
dismiss()
```

`schedule(for:)` calls `cancel` internally when `reminderTime` is nil, so this handles both enable and disable cases without branching on `reminderEnabled`.

---

## TodayView changes

In the existing `.task { await verifyAll() }`, add the reschedule call:

```swift
.task {
    await NotificationScheduler.rescheduleAll(habits)
    await verifyAll()
}
```

`habits` is the existing `@Query` property — no new query needed. `rescheduleAll` runs first so the notification set is fresh before any verification completes.

---

## SettingsView Notifications section

Replace `Text("Reminder settings coming soon")` with a view that:

1. Loads `UNUserNotificationCenter.current().notificationSettings().authorizationStatus` in `.task`.
2. Stores it in `@State var authStatus: UNAuthorizationStatus = .notDetermined`.
3. Renders based on status:

| Status | UI |
|---|---|
| `.notDetermined` | Caption: "Allow notifications to receive habit reminders." + Button: "Allow Notifications" (calls `await NotificationScheduler.requestAuthorization()`, then re-checks status) |
| `.authorized` / `.provisional` | Text: "Notifications enabled" + caption: "Reminders are set per-habit in the Habits tab." |
| `.denied` | Text: "Notifications are blocked." + (iOS only) Button: "Open Settings" using `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` |
| `.ephemeral` | Same as `.authorized` |

On macOS, when status is `.denied`, show only the "Notifications are blocked" text — no Settings button (deep-linking to System Settings is unreliable).

---

## Package.swift

Add `"Connectors/NotificationScheduler.swift"` to the exclude list in the `ChainDomain` target — it imports `UserNotifications` which is not available in the SPM test target.

---

## Out of Scope (v1)

- Notification actions (e.g., "Mark Done" button in the notification)
- Per-weekday scheduling for weekly habits
- Notification badges on the app icon
- Delivered-notification history
