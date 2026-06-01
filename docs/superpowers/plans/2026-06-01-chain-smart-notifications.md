# Chain Smart Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three user-configurable smart notifications (end-of-day nudge, streak-at-risk alert, weekly summary) that auto-cancel when all habits are verified.

**Architecture:** A new `SmartNotificationScheduler` enum handles scheduling/cancellation based on `UserDefaults` prefs. `TodayView` drives rescheduling on load, after auto-verify, and after each manual verify tap. `SettingsView` gains a three-row notification config section with toggles and time pickers.

**Tech Stack:** `UNUserNotificationCenter`, `UNCalendarNotificationTrigger`, `@AppStorage`, SwiftData `@Query`, `UserDefaults.register(defaults:)`.

---

## Context

Chain habit streak app — SwiftUI multiplatform macOS 14 + iOS 17, SwiftData, SPM `ChainDomain` target.

Run tests with:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected baseline: **68 tests pass**.

`SmartNotificationScheduler` imports `UserNotifications` — not available in the headless SPM build. It must be excluded from SPM like `NotificationScheduler.swift` already is. No new SPM tests for this component; verify no regressions with the existing 68 tests after each task.

---

## File map

| File | Action |
|---|---|
| `Chain/Connectors/SmartNotificationScheduler.swift` | Create — full scheduling/cancellation logic |
| `Package.swift` | Modify — add SmartNotificationScheduler to SPM exclude list |
| `Chain/ChainApp.swift` | Modify — register UserDefaults defaults in `init()` |
| `Chain/Views/Today/TodayView.swift` | Modify — call `rescheduleForToday` in `.task`, `.refreshable`, `onVerify` |
| `Chain/Views/Settings/SettingsView.swift` | Modify — replace static "enabled" text with three notification config rows |

---

## Task 1: SmartNotificationScheduler + Package.swift exclusion

**Files:**
- Create: `Chain/Connectors/SmartNotificationScheduler.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Add exclusion to Package.swift**

Open `Package.swift`. In the `exclude` array of the `ChainDomain` target, add `"Connectors/SmartNotificationScheduler.swift"` after the existing `NotificationScheduler` entry. The full exclude array becomes:

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
    "Connectors/NotificationScheduler.swift",
    "Connectors/SmartNotificationScheduler.swift"
],
```

- [ ] **Step 2: Create SmartNotificationScheduler.swift**

Create `Chain/Connectors/SmartNotificationScheduler.swift` with the following complete contents:

```swift
import UserNotifications
import Foundation

enum SmartNotificationScheduler {

    static let nudgeID  = "smart-nudge-today"
    static let atRiskID = "smart-at-risk-today"
    static let weeklyID = "smart-weekly-summary"

    static func rescheduleForToday(habits: [Habit]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let allVerified = habits.allSatisfy { habit in
            let periodStart = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.first { $0.periodStart == periodStart }?.status == .verified
        }

        if allVerified {
            center.removePendingNotificationRequests(withIdentifiers: [nudgeID, atRiskID])
        } else {
            if UserDefaults.standard.bool(forKey: "nudgeEnabled") {
                await scheduleDaily(
                    id: nudgeID,
                    title: "Don't forget your habits today! 🔥",
                    body: "Keep your streak alive — check in before midnight.",
                    hour: UserDefaults.standard.integer(forKey: "nudgeHour"),
                    minute: UserDefaults.standard.integer(forKey: "nudgeMinute")
                )
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [nudgeID])
            }

            if UserDefaults.standard.bool(forKey: "atRiskEnabled") {
                await scheduleDaily(
                    id: atRiskID,
                    title: "Some streaks are at risk — check in before midnight! ⚠️",
                    body: "Don't break the chain.",
                    hour: UserDefaults.standard.integer(forKey: "atRiskHour"),
                    minute: UserDefaults.standard.integer(forKey: "atRiskMinute")
                )
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [atRiskID])
            }
        }

        if UserDefaults.standard.bool(forKey: "weeklyEnabled") {
            await scheduleWeekly(
                id: weeklyID,
                title: "How did your habits go this week? 📊",
                body: "Tap to review your progress.",
                hour: UserDefaults.standard.integer(forKey: "weeklyHour"),
                minute: UserDefaults.standard.integer(forKey: "weeklyMinute")
            )
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [weeklyID])
        }
    }

    private static func scheduleDaily(id: String, title: String, body: String, hour: Int, minute: Int) async {
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

    private static func scheduleWeekly(id: String, title: String, body: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 3: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass. The new file is excluded from SPM so it won't be compiled.

- [ ] **Step 4: Commit**

```bash
git add Chain/Connectors/SmartNotificationScheduler.swift Package.swift
git commit -m "feat: add SmartNotificationScheduler with nudge/at-risk/weekly logic"
```

---

## Task 2: Register UserDefaults defaults

**Files:**
- Modify: `Chain/ChainApp.swift`

The nine `@AppStorage` keys need registered defaults so they return correct values on first launch before the user visits Settings. Defaults are registered in `ChainApp.init()` before the container is created.

- [ ] **Step 1: Update ChainApp.init()**

Open `Chain/ChainApp.swift`. Replace the current `init()`:

```swift
init() {
    do {
        container = try ModelContainerFactory.make()
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}
```

With:

```swift
init() {
    UserDefaults.standard.register(defaults: [
        "nudgeEnabled": true,
        "nudgeHour": 21,
        "nudgeMinute": 0,
        "atRiskEnabled": true,
        "atRiskHour": 22,
        "atRiskMinute": 0,
        "weeklyEnabled": true,
        "weeklyHour": 20,
        "weeklyMinute": 0
    ])
    do {
        container = try ModelContainerFactory.make()
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}
```

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/ChainApp.swift
git commit -m "feat: register UserDefaults defaults for smart notification prefs"
```

---

## Task 3: Wire TodayView

**Files:**
- Modify: `Chain/Views/Today/TodayView.swift`

Three call sites need `SmartNotificationScheduler.rescheduleForToday(habits: habits)`:
1. After `verifyAll()` in the `.task` modifier (runs on load)
2. In `.refreshable` (after pull-to-refresh verify)
3. Inside each `HabitRowView`'s `onVerify` closure (after each manual tap)

- [ ] **Step 1: Replace TodayView body with wired version**

Open `Chain/Views/Today/TodayView.swift`. Replace the entire `body` property:

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Greeting + progress
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.title2.bold())
                if !habits.isEmpty {
                    Text("\(doneCount) of \(habits.count) done today")
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(
                                    width: geo.size.width * (Double(doneCount) / Double(habits.count)),
                                    height: 8
                                )
                                .animation(.spring(response: 0.4), value: doneCount)
                        }
                    }
                    .frame(height: 8)
                }
            }

            // Companion card
            if let companion = companions.first {
                CompanionCardView(companion: companion, habits: habits)
            }

            // Habit list
            if habits.isEmpty {
                ContentUnavailableView(
                    "No habits yet",
                    systemImage: "target",
                    description: Text("Go to Habits to add your first one.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(habits) { habit in
                    HabitRowView(habit: habit) {
                        HabitVerifier.verify(habit, allHabits: habits, context: context, companions: companions)
                        Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
                    }
                }
            }
        }
        .padding()
    }
    .navigationTitle("Today")
    .task {
        await NotificationScheduler.rescheduleAll(habits)
        await verifyAll()
        await SmartNotificationScheduler.rescheduleForToday(habits: habits)
    }
    .refreshable {
        await verifyAll()
        await SmartNotificationScheduler.rescheduleForToday(habits: habits)
    }
}
```

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Today/TodayView.swift
git commit -m "feat: wire SmartNotificationScheduler into TodayView"
```

---

## Task 4: SettingsView smart notification section

**Files:**
- Modify: `Chain/Views/Settings/SettingsView.swift`

Replace the static "Notifications enabled" label in `notificationStatusView` with three configurable notification rows (toggle + time picker each). Add `@Query var habits` and `import SwiftData`. Add a private `NotificationRowView` struct that owns `@AppStorage` bindings for its row's key set.

- [ ] **Step 1: Replace SettingsView.swift with the full updated version**

Replace the entire contents of `Chain/Views/Settings/SettingsView.swift` with:

```swift
import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
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
            Group {
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

private struct NotificationRowView: View {
    let label: String
    let enabledDefault: Bool
    let hourDefault: Int
    let minuteDefault: Int
    let habits: [Habit]

    @AppStorage private var enabled: Bool
    @AppStorage private var hour: Int
    @AppStorage private var minute: Int

    init(label: String,
         enabledKey: String, enabledDefault: Bool,
         hourKey: String, hourDefault: Int,
         minuteKey: String, minuteDefault: Int,
         habits: [Habit]) {
        self.label = label
        self.enabledDefault = enabledDefault
        self.hourDefault = hourDefault
        self.minuteDefault = minuteDefault
        self.habits = habits
        _enabled = AppStorage(wrappedValue: enabledDefault, enabledKey)
        _hour    = AppStorage(wrappedValue: hourDefault,    hourKey)
        _minute  = AppStorage(wrappedValue: minuteDefault,  minuteKey)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour   = comps.hour   ?? hourDefault
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

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Settings/SettingsView.swift
git commit -m "feat: add smart notification config rows to SettingsView"
```
