# Chain Streak Milestones — Design Spec
**Date:** 2026-05-31
**Status:** Approved

---

## Overview

Celebrate when a user hits a streak milestone (7, 14, 30, 60, 100 days). On a manual verify tap: show full-screen confetti + a "N-day streak!" card, and fire an immediate local notification. On an auto-verify (HealthKit/MCP): fire the notification only — no confetti since the user isn't interacting.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Domain/MilestoneChecker.swift` | Pure enum: checks if a streak Int is a milestone; testable in SPM |
| `Chain/Views/Today/MilestoneOverlayView.swift` | Full-screen confetti + milestone card; also defines `MilestoneCelebration` struct |

### Modified files

| File | Change |
|---|---|
| `Chain/Views/Today/HabitRowView.swift` | After verify tap, compute streak, check milestone, show `.fullScreenCover` + fire notification |
| `Chain/Connectors/ConnectorService.swift` | After auto-verify, compute streak, check milestone, fire notification only |
| `Chain/Connectors/NotificationScheduler.swift` | Add `scheduleMilestone(for:streak:)` |

### No changes to

- `TodayView` — milestone overlay is presented directly from `HabitRowView` via `.fullScreenCover`
- SwiftData models
- `HabitVerifier` — already synchronous, entry is saved before control returns to HabitRowView

---

## MilestoneChecker

`Chain/Domain/MilestoneChecker.swift`

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

Lives in `Chain/Domain/` — pure Foundation, no SwiftData, fully testable via SPM.

---

## MilestoneOverlayView

`Chain/Views/Today/MilestoneOverlayView.swift`

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

    // 20 particles: deterministic layout, 5 emoji types cycling
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

---

## HabitRowView changes

After the verify tap fires `onVerify()` (synchronous — `HabitVerifier.verify` is `@MainActor` and saves before returning), immediately compute the streak and check for a milestone.

Add:
- `@State private var milestoneCelebration: MilestoneCelebration?`
- A helper `checkMilestone()` that computes streak using `StreakCalculator.current` and sets `milestoneCelebration` if needed
- `.fullScreenCover(item: $milestoneCelebration)` presenting `MilestoneOverlayView`

```swift
// In the manual-verify button action:
Button {
    onVerify()
    checkMilestone()
} label: {
    Image(systemName: "circle")...
}

// New helper:
private func checkMilestone() {
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
    milestoneCelebration = MilestoneCelebration(habit: habit, streak: milestone)
    Task { await NotificationScheduler.scheduleMilestone(for: habit, streak: milestone) }
}

// On the outer VStack/HStack body:
.fullScreenCover(item: $milestoneCelebration) { celebration in
    MilestoneOverlayView(habit: celebration.habit, streak: celebration.streak) {
        milestoneCelebration = nil
    }
}
```

---

## ConnectorService changes

In `applyResult(_:to:context:)`, after saving the entry and only when `result.status == .verified`, compute the streak and fire the milestone notification.

```swift
@MainActor
private func applyResult(_ result: VerificationResult, to habit: Habit, context: ModelContext) {
    // ... existing entry creation/update and context.save() ...

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
```

No confetti here — auto-verification happens without user interaction.

---

## NotificationScheduler.scheduleMilestone

Add to `Chain/Connectors/NotificationScheduler.swift`:

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

The identifier includes both habit ID and streak count so different milestones for the same habit don't overwrite each other.

---

## Tests

`MilestoneChecker` is SPM-testable:
- `milestone(for: 7)` → `7`
- `milestone(for: 14)` → `14`
- `milestone(for: 30)` → `30`
- `milestone(for: 60)` → `60`
- `milestone(for: 100)` → `100`
- `milestone(for: 1)` → `nil`
- `milestone(for: 15)` → `nil`
- `milestone(for: 0)` → `nil`

---

## Out of Scope (v1)

- Haptic feedback on milestone
- Per-device "don't celebrate twice" persistence (same milestone can re-fire if app is deleted and reinstalled)
- Confetti on the menu bar popover
- Custom milestone numbers per habit
