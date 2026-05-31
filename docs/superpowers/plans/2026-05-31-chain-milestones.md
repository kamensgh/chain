# Chain Streak Milestones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Celebrate 7/14/30/60/100-day streaks with full-screen confetti on manual verify taps and a local notification on both manual and auto-verifications.

**Architecture:** `MilestoneChecker` (pure domain enum, SPM-testable) detects milestone streak counts. `MilestoneOverlayView` (SwiftUI) shows falling-emoji confetti + a dismissable card. `HabitRowView` calls `checkMilestone()` after each manual verify tap; `ConnectorService.applyResult` fires a milestone notification after any auto-verify. `NotificationScheduler` gains a `scheduleMilestone(for:streak:)` method using a 1-second `UNTimeIntervalNotificationTrigger`.

**Tech Stack:** Swift Testing (`@Test`, `#expect`), SwiftUI `.fullScreenCover`, `UNTimeIntervalNotificationTrigger`, `StreakCalculator` (existing), SPM `ChainDomain` target for domain tests.

---

## Context

Chain is a SwiftUI multiplatform habit-streak app (macOS 14 + iOS 17), SwiftData. Run tests with:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected baseline: **60 tests pass**.

Key existing types you will use:
- `StreakEntry(periodStart: Date, status: EntryStatus)` — in `Chain/Domain/StreakCalculator.swift`
- `StreakCalculator.current(entries: [StreakEntry], frequency: Frequency, today: Date, gracePeriod: Bool) -> Int`
- `HabitRowView.currentStreak: Int` — already computed via `StreakCalculator.current` on `habit.entries`
- `NotificationScheduler` enum in `Chain/Connectors/NotificationScheduler.swift`

`NotificationScheduler`, `ConnectorService`, and `HabitRowView` are **excluded from SPM** (they import `UserNotifications`, `HealthKit`, or `SwiftUI`). Only `MilestoneChecker` has SPM tests.

---

## File map

| File | Action |
|---|---|
| `Chain/Domain/MilestoneChecker.swift` | Create — pure enum, `milestone(for:) -> Int?` |
| `ChainTests/MilestoneCheckerTests.swift` | Create — 8 SPM tests |
| `Chain/Connectors/NotificationScheduler.swift` | Modify — add `scheduleMilestone(for:streak:)` |
| `Chain/Views/Today/MilestoneOverlayView.swift` | Create — `MilestoneCelebration` struct + confetti view |
| `Chain/Views/Today/HabitRowView.swift` | Modify — add `checkMilestone()`, `milestoneCelebration` state, `.fullScreenCover` |
| `Chain/Connectors/ConnectorService.swift` | Modify — call milestone notification in `applyResult` |

---

## Task 1: MilestoneChecker (TDD)

**Files:**
- Create: `Chain/Domain/MilestoneChecker.swift`
- Create: `ChainTests/MilestoneCheckerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `ChainTests/MilestoneCheckerTests.swift`:

```swift
import Testing
@testable import ChainDomain

struct MilestoneCheckerTests {

    @Test func milestone7()   { #expect(MilestoneChecker.milestone(for: 7)   == 7)   }
    @Test func milestone14()  { #expect(MilestoneChecker.milestone(for: 14)  == 14)  }
    @Test func milestone30()  { #expect(MilestoneChecker.milestone(for: 30)  == 30)  }
    @Test func milestone60()  { #expect(MilestoneChecker.milestone(for: 60)  == 60)  }
    @Test func milestone100() { #expect(MilestoneChecker.milestone(for: 100) == 100) }
    @Test func nonMilestone1()  { #expect(MilestoneChecker.milestone(for: 1)  == nil) }
    @Test func nonMilestone15() { #expect(MilestoneChecker.milestone(for: 15) == nil) }
    @Test func zero()           { #expect(MilestoneChecker.milestone(for: 0)  == nil) }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MilestoneCheckerTests
```

Expected: compile error — `MilestoneChecker` not found.

- [ ] **Step 3: Implement MilestoneChecker**

Create `Chain/Domain/MilestoneChecker.swift`:

```swift
import Foundation

enum MilestoneChecker {
    static let milestones: Set<Int> = [7, 14, 30, 60, 100]

    /// Returns the milestone if `streak` is exactly one of the milestone values, nil otherwise.
    static func milestone(for streak: Int) -> Int? {
        milestones.contains(streak) ? streak : nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **68 tests pass** (60 existing + 8 new).

- [ ] **Step 5: Commit**

```bash
git add Chain/Domain/MilestoneChecker.swift ChainTests/MilestoneCheckerTests.swift
git commit -m "feat: add MilestoneChecker domain enum with tests"
```

---

## Task 2: NotificationScheduler.scheduleMilestone

**Files:**
- Modify: `Chain/Connectors/NotificationScheduler.swift`

Add `scheduleMilestone(for:streak:)` to the existing `NotificationScheduler` enum. The identifier includes both habit ID and streak count so multiple milestones for the same habit don't overwrite each other.

- [ ] **Step 1: Add scheduleMilestone to NotificationScheduler**

Open `Chain/Connectors/NotificationScheduler.swift`. After the closing brace of `rescheduleAll`, add:

```swift
    static func scheduleMilestone(for habit: Habit, streak: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streak)-Day Streak!"
        content.body = "\(habit.emoji) \(habit.name) — you're on fire!"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "milestone-\(habit.id.uuidString)-\(streak)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
```

The full updated file becomes:

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

    static func scheduleMilestone(for habit: Habit, streak: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streak)-Day Streak!"
        content.body = "\(habit.emoji) \(habit.name) — you're on fire!"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "milestone-\(habit.id.uuidString)-\(streak)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass. `NotificationScheduler` is excluded from SPM — no compilation impact.

- [ ] **Step 3: Commit**

```bash
git add Chain/Connectors/NotificationScheduler.swift
git commit -m "feat: add scheduleMilestone to NotificationScheduler"
```

---

## Task 3: MilestoneOverlayView

**Files:**
- Create: `Chain/Views/Today/MilestoneOverlayView.swift`

`MilestoneCelebration` is an `Identifiable` struct used as the `.fullScreenCover(item:)` state in HabitRowView (Task 4). Defines it here so both files are in the same compilation unit without any extra imports.

- [ ] **Step 1: Create MilestoneOverlayView.swift**

Create `Chain/Views/Today/MilestoneOverlayView.swift`:

```swift
import SwiftUI

struct MilestoneCelebration: Identifiable {
    let id = UUID()
    let habit: Habit
    let streak: Int
}

struct MilestoneOverlayView: View {
    let habit: Habit
    let streak: Int
    let onDismiss: () -> Void

    @State private var animating = false

    private let particles: [(emoji: String, x: CGFloat, delay: Double)] = {
        let emojis = ["🎉", "⭐", "🔥", "✨", "💫"]
        return (0..<20).map { i in
            (emoji: emojis[i % emojis.count],
             x: CGFloat(i) / 19.0,
             delay: Double(i) * 0.08)
        }
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(0..<particles.count, id: \.self) { i in
                    Text(particles[i].emoji)
                        .font(.title)
                        .position(
                            x: particles[i].x * geo.size.width,
                            y: animating ? geo.size.height + 60 : -60
                        )
                        .animation(
                            .easeIn(duration: 1.8).delay(particles[i].delay),
                            value: animating
                        )
                }
            }

            VStack(spacing: 12) {
                Text("🔥")
                    .font(.system(size: 64))
                    .scaleEffect(animating ? 1.2 : 0.6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: animating)

                Text("\(streak)-day streak!")
                    .font(.title.bold())

                Text("\(habit.emoji) \(habit.name) is on fire!")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Keep it up!") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            animating = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                onDismiss()
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
git add Chain/Views/Today/MilestoneOverlayView.swift
git commit -m "feat: add MilestoneOverlayView with confetti animation"
```

---

## Task 4: HabitRowView — manual verify trigger

**Files:**
- Modify: `Chain/Views/Today/HabitRowView.swift`

`HabitRowView` already has a `currentStreak: Int` computed property (lines 26–34) that calls `StreakCalculator.current` on `habit.entries`. Use it directly in `checkMilestone()` to avoid duplicating the calculation.

- [ ] **Step 1: Add milestone state, helper, and fullScreenCover to HabitRowView**

Replace the entire contents of `Chain/Views/Today/HabitRowView.swift` with:

```swift
import SwiftUI
import SwiftData

struct HabitRowView: View {
    let habit: Habit
    let onVerify: () -> Void

    @State private var showingScreenshotPicker = false
    @State private var milestoneCelebration: MilestoneCelebration?

    private var currentPeriodStart: Date {
        HabitScheduler.periodStart(for: habit.frequency, on: Date())
    }

    private var currentEntry: HabitEntry? {
        habit.entries.first { $0.periodStart == currentPeriodStart }
    }

    private var isVerified: Bool {
        currentEntry?.status == .verified
    }

    private var currentStreak: Int {
        let streakEntries = habit.entries.map {
            StreakEntry(periodStart: $0.periodStart, status: $0.status)
        }
        return StreakCalculator.current(
            entries: streakEntries,
            frequency: habit.frequency,
            today: Date(),
            gracePeriod: habit.gracePeriodEnabled
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji circle
            ZStack {
                Circle()
                    .fill(isVerified ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 46, height: 46)
                Text(habit.emoji)
                    .font(.title3)
            }

            // Name + status + source label
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(isVerified ? .green : .secondary)
                if let entry = currentEntry, isVerified, entry.verifMethod == .auto,
                   let label = entry.sourceLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Streak badge
            if currentStreak > 0 {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            // Check button / done indicator
            if isVerified {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            } else if habit.connectorType == .screenshot {
                Button {
                    showingScreenshotPicker = true
                } label: {
                    Image(systemName: "camera.circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onVerify()
                    checkMilestone()
                } label: {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showingScreenshotPicker) {
            ScreenshotPickerView(habit: habit)
        }
        .fullScreenCover(item: $milestoneCelebration) { celebration in
            MilestoneOverlayView(habit: celebration.habit, streak: celebration.streak) {
                milestoneCelebration = nil
            }
        }
    }

    private var statusLabel: String {
        guard let entry = currentEntry else {
            return "Tap to mark done"
        }
        switch entry.status {
        case .verified:
            if let value = entry.value {
                return "\(Int(value)) \(habit.goalConfig.unit.rawValue)"
            }
            return "Done ✓"
        case .pending:  return "Pending"
        case .skipped:  return "Skipped"
        }
    }

    private func checkMilestone() {
        guard let milestone = MilestoneChecker.milestone(for: currentStreak) else { return }
        milestoneCelebration = MilestoneCelebration(habit: habit, streak: milestone)
        Task { await NotificationScheduler.scheduleMilestone(for: habit, streak: milestone) }
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
git add Chain/Views/Today/HabitRowView.swift
git commit -m "feat: show milestone confetti overlay on manual verify"
```

---

## Task 5: ConnectorService — auto-verify milestone notification

**Files:**
- Modify: `Chain/Connectors/ConnectorService.swift`

After `applyResult` saves the entry, check whether the new streak is a milestone and fire `scheduleMilestone` if so. No confetti here — auto-verification happens in the background without user interaction.

- [ ] **Step 1: Update applyResult in ConnectorService**

Replace the entire contents of `Chain/Connectors/ConnectorService.swift` with:

```swift
import Foundation
import SwiftData
import HealthKit

final class ConnectorService {
    static let shared = ConnectorService()
    private init() {}

    func verify(habit: Habit, context: ModelContext) async {
        guard let connector = makeConnector(for: habit) else { return }
        do {
            let result = try await connector.verify(goalConfig: habit.goalConfig)
            await MainActor.run { applyResult(result, to: habit, context: context) }
        } catch {
            // Network / HealthKit permission failures are normal — don't surface them as crashes
        }
    }

    // MARK: - Factory

    private func makeConnector(for habit: Habit) -> (any HabitConnector)? {
        switch habit.connectorType {
        case .manual:
            return ManualConnector()
        case .screenshot:
            return nil  // Screenshot-type habits are verified through ScreenshotPickerView, not here
        case .mcp:
            guard let endpointStr = habit.connectorEndpoint,
                  let url = URL(string: endpointStr) else { return nil }
            let credential = KeychainHelper.load(for: habit.id.uuidString)
            return MCPConnector(endpoint: url, credential: credential)
        case .healthKitSteps:
            return HealthKitConnector(store: HKHealthStore(), dataType: .steps)
        case .healthKitWorkout:
            return HealthKitConnector(store: HKHealthStore(), dataType: .workoutMinutes)
        case .healthKitSleep:
            return HealthKitConnector(store: HKHealthStore(), dataType: .sleepHours)
        }
    }

    // MARK: - Result application (must run on MainActor)

    @MainActor
    private func applyResult(_ result: VerificationResult, to habit: Habit, context: ModelContext) {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
            guard existing.status != .verified else { return }
            existing.status = result.status
            existing.verifMethod = result.verifMethod
            existing.value = result.value
            existing.sourceLabel = result.sourceLabel
            existing.verifiedAt = result.status == .verified ? Date() : nil
        } else {
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = result.status
            entry.verifMethod = result.verifMethod
            entry.value = result.value
            entry.sourceLabel = result.sourceLabel
            entry.verifiedAt = result.status == .verified ? Date() : nil
            context.insert(entry)
        }
        try? context.save()

        guard result.status == .verified else { return }
        let streakEntries = habit.entries.map {
            StreakEntry(periodStart: $0.periodStart, status: $0.status)
        }
        let streak = StreakCalculator.current(
            entries: streakEntries,
            frequency: habit.frequency,
            today: Date(),
            gracePeriod: habit.gracePeriodEnabled
        )
        guard let milestone = MilestoneChecker.milestone(for: streak) else { return }
        Task { await NotificationScheduler.scheduleMilestone(for: habit, streak: milestone) }
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
git add Chain/Connectors/ConnectorService.swift
git commit -m "feat: fire milestone notification on auto-verify in ConnectorService"
```
