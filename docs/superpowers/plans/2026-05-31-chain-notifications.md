# Chain Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up `UNUserNotificationCenter` daily reminders for habits using the `reminderTime: Date?` field that already exists on the `Habit` model.

**Architecture:** A new `NotificationScheduler` enum wraps `UNUserNotificationCenter` calls. `AddHabitView.save()` schedules/cancels after each save. `TodayView.task` reschedules all on app launch. `SettingsView` gets a live permission-status UI replacing its placeholder.

**Tech Stack:** `UserNotifications` framework, `UNCalendarNotificationTrigger`, `UNUserNotificationCenter`, SwiftUI `@State`, `#if os(iOS)` for Settings URL. No SPM tests (UserNotifications unavailable in headless SPM builds).

---

## File map

| File | Action |
|---|---|
| `Chain/Connectors/NotificationScheduler.swift` | Create — schedule, cancel, rescheduleAll, requestAuthorization |
| `Package.swift` | Modify — add NotificationScheduler.swift to SPM exclude list |
| `Chain/Views/Habits/AddHabitView.swift` | Modify — call schedule/cancel in save() |
| `Chain/Views/Today/TodayView.swift` | Modify — add rescheduleAll to .task |
| `Chain/Views/Settings/SettingsView.swift` | Modify — replace placeholder with permission UI |

---

## Task 1: NotificationScheduler + Package.swift exclusion

**Files:**
- Create: `Chain/Connectors/NotificationScheduler.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Create NotificationScheduler**

Create `Chain/Connectors/NotificationScheduler.swift`:

```swift
import UserNotifications
import Foundation

enum NotificationScheduler {

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func schedule(for habit: Habit) async {
        guard let reminderTime = habit.reminderTime else {
            cancel(for: habit)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "\(habit.emoji) \(habit.name)"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: habit.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for habit: Habit) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [habit.id.uuidString])
    }

    static func rescheduleAll(_ habits: [Habit]) async {
        let identifiers = habits.map { $0.id.uuidString }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
        for habit in habits where habit.reminderTime != nil {
            await schedule(for: habit)
        }
    }
}
```

- [ ] **Step 2: Exclude NotificationScheduler from SPM**

In `Package.swift`, add `"Connectors/NotificationScheduler.swift"` to the `exclude` array. The full updated exclude list:

```swift
exclude: [
    "ChainApp.swift",
    "Info.plist",
    "Assets.xcassets",
    "Views",
    "ContentView.swift",
    "Models/Habit.swift",
    "Models/HabitEntry.swift",
    "Models/Companion.swift",
    "Connectors/HealthKitConnector.swift",
    "Connectors/ConnectorService.swift",
    "Connectors/HabitVerifier.swift",
    "Connectors/NotificationScheduler.swift"
],
```

- [ ] **Step 3: Run tests to verify SPM still builds cleanly**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass. If there are compile errors, the exclusion is missing or misspelled.

- [ ] **Step 4: Commit**

```bash
git add Chain/Connectors/NotificationScheduler.swift Package.swift
git commit -m "feat: add NotificationScheduler for habit reminders"
```

---

## Task 2: AddHabitView — schedule/cancel on save

**Files:**
- Modify: `Chain/Views/Habits/AddHabitView.swift`

The current `save()` method (lines 117–135) sets `h.reminderTime` but never calls the scheduler. Add `Task { await NotificationScheduler.schedule(for: h) }` to both the edit and create paths, immediately before `try? context.save()`.

- [ ] **Step 1: Update save() in AddHabitView**

Replace the entire `save()` function with:

```swift
private func save() {
    let goal = GoalConfig(unit: goalUnit, targetValue: goalTarget, customLabel: "")
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    if let h = habit {
        h.name = trimmedName
        h.emoji = emoji
        h.frequency = frequency
        h.goalConfig = goal
        h.connectorType = connectorType
        h.gracePeriodEnabled = gracePeriodEnabled
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
}
```

`NotificationScheduler.schedule(for:)` calls `cancel` internally when `reminderTime` is nil — so disabling a reminder and saving correctly removes the pending notification.

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Habits/AddHabitView.swift
git commit -m "feat: schedule/cancel notification when saving habit reminder"
```

---

## Task 3: TodayView — rescheduleAll on launch

**Files:**
- Modify: `Chain/Views/Today/TodayView.swift`

`TodayView` already has `.task { await verifyAll() }` (line 68) and `@Query(sort: \Habit.createdAt) private var habits`. Add `rescheduleAll` before `verifyAll` in that task so the notification set is always in sync with the current habits when the app becomes active.

- [ ] **Step 1: Update .task in TodayView**

Change line 68 from:

```swift
.task { await verifyAll() }
```

to:

```swift
.task {
    await NotificationScheduler.rescheduleAll(habits)
    await verifyAll()
}
```

No other changes to TodayView.

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Today/TodayView.swift
git commit -m "feat: reschedule all habit notifications on TodayView appear"
```

---

## Task 4: SettingsView — live notification permission UI

**Files:**
- Modify: `Chain/Views/Settings/SettingsView.swift`

Replace the placeholder `Text("Reminder settings coming soon")` with a live authorization-status UI that loads on `.task` and shows different content for each `UNAuthorizationStatus` case.

- [ ] **Step 1: Replace SettingsView**

Replace the entire contents of `Chain/Views/Settings/SettingsView.swift` with:

```swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section("Companion") {
                CompanionSettingsView()
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Notifications") {
                notificationStatusView
            }

            Section("Connectors") {
                Text("App connections coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task {
            authStatus = await UNUserNotificationCenter.current()
                .notificationSettings().authorizationStatus
        }
    }

    @ViewBuilder
    private var notificationStatusView: some View {
        switch authStatus {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow notifications to receive habit reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Allow Notifications") {
                    Task {
                        await NotificationScheduler.requestAuthorization()
                        authStatus = await UNUserNotificationCenter.current()
                            .notificationSettings().authorizationStatus
                    }
                }
            }
        case .authorized, .provisional, .ephemeral:
            VStack(alignment: .leading, spacing: 4) {
                Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Reminders are set per-habit in the Habits tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications are blocked.")
                    .foregroundStyle(.secondary)
                #if os(iOS)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif
            }
        @unknown default:
            EmptyView()
        }
    }
}
```

- [ ] **Step 2: Run full test suite**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass.

- [ ] **Step 3: Build check in Xcode**

Build for macOS (`Cmd+B`). Navigate to Settings → Notifications section. Verify:
- On first run (permission not yet requested): shows "Allow Notifications" button
- Tapping the button triggers the system permission dialog
- After granting: shows "Notifications enabled ✓"
- After denying: shows "Notifications are blocked." (+ "Open Settings" on iOS)

- [ ] **Step 4: Commit**

```bash
git add Chain/Views/Settings/SettingsView.swift
git commit -m "feat: add live notification permission UI to SettingsView"
```
