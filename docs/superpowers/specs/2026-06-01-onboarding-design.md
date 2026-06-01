# Chain Onboarding — Design Spec
**Date:** 2026-06-01
**Status:** Approved

---

## Overview

A 3-screen first-launch onboarding flow: Welcome → Permissions → First Habit. Shown once via `.fullScreenCover` gated on a `@AppStorage` flag. After the user creates their first habit the cover dismisses and they land on Today with a habit already waiting.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Views/Onboarding/OnboardingView.swift` | Container — `step` state, step switching, `OnboardingStep` enum |
| `Chain/Views/Onboarding/WelcomeStepView.swift` | Screen 1: centered logo + tagline + "Get Started" |
| `Chain/Views/Onboarding/PermissionsStepView.swift` | Screen 2: HealthKit + notifications explanation + "Continue" |
| `Chain/Views/Onboarding/FirstHabitStepView.swift` | Screen 3: name field + frequency picker + "Start My Streak" |

### Modified files

| File | Change |
|---|---|
| `Chain/ContentView.swift` | Add `@AppStorage("hasCompletedOnboarding")` + `.fullScreenCover` presenting `OnboardingView` |

### No changes to

- SwiftData models
- `AddHabitView` — the first-habit screen is a standalone minimal form, not a reuse of `AddHabitView`
- `NotificationScheduler` — called as-is from `PermissionsStepView`

---

## Gating

`ContentView` holds:

```swift
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
```

And presents onboarding via:

```swift
.fullScreenCover(isPresented: .init(
    get: { !hasCompletedOnboarding },
    set: { if !$0 { hasCompletedOnboarding = true } }
)) {
    OnboardingView {
        hasCompletedOnboarding = true
    }
}
```

Works on iOS 17 and macOS 14. Once set to `true`, onboarding never shows again unless the key is manually reset (useful for testing via `UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")`).

`UserDefaults.standard.register(defaults:)` in `ChainApp.init()` does NOT register a default for `hasCompletedOnboarding` — omitting a default means it starts as `false`, which is correct.

---

## OnboardingView

`Chain/Views/Onboarding/OnboardingView.swift`

```swift
import SwiftUI

enum OnboardingStep {
    case welcome, permissions, firstHabit
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        switch step {
        case .welcome:
            WelcomeStepView { step = .permissions }
        case .permissions:
            PermissionsStepView { step = .firstHabit }
        case .firstHabit:
            FirstHabitStepView(onComplete: onComplete)
        }
    }
}
```

No back navigation — the flow is linear and short.

---

## WelcomeStepView

`Chain/Views/Onboarding/WelcomeStepView.swift`

Centered layout on a black background:

- Large emoji in an accent-colored circle: `⛓️` at `.system(size: 72)` inside a `Circle().fill(Color.accentColor.opacity(0.2))` of diameter 120
- App name: `Text("Chain")` at `.largeTitle.bold()`
- Tagline: `Text("Build habits that stick — verified automatically.")` at `.subheadline`, `.secondary` foreground, centered, max width 260
- "Get Started" button at the bottom: `.borderedProminent` style, calls `onNext()`

```swift
struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                    Text("⛓️")
                        .font(.system(size: 72))
                }
                Text("Chain")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                Text("Build habits that stick —\nverified automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .frame(maxWidth: 260)
                Spacer()
                Button("Get Started", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
        }
    }
}
```

---

## PermissionsStepView

`Chain/Views/Onboarding/PermissionsStepView.swift`

Two explanation cards then a "Continue" button. Declining either permission is not a blocker — the button always advances.

```swift
import SwiftUI
import HealthKit

struct PermissionsStepView: View {
    let onNext: () -> Void
    @State private var requesting = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A couple of permissions")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Chain works best with access to these.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 12) {
                    PermissionCard(
                        emoji: "❤️",
                        title: "Health",
                        description: "Reads steps, workouts, sleep, and more to verify habits automatically."
                    )
                    PermissionCard(
                        emoji: "🔔",
                        title: "Notifications",
                        description: "Reminds you to check in and celebrates streak milestones."
                    )
                }

                Spacer()

                Button {
                    Task { await requestPermissions() }
                } label: {
                    if requesting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(requesting)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
        }
    }

    private func requestPermissions() async {
        requesting = true
        // HealthKit
        let store = HKHealthStore()
        if HKHealthStore.isHealthDataAvailable() {
            let readTypes: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.workoutType()
            ]
            try? await store.requestAuthorization(toShare: [], read: readTypes)
        }
        // Notifications
        await NotificationScheduler.requestAuthorization()
        requesting = false
        onNext()
    }
}

private struct PermissionCard: View {
    let emoji: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## FirstHabitStepView

`Chain/Views/Onboarding/FirstHabitStepView.swift`

Name field + frequency picker. "Start My Streak" disabled when name is empty. On tap: creates `Habit`, saves to `modelContext`, calls `onComplete()`.

```swift
import SwiftUI
import SwiftData

struct FirstHabitStepView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var frequency: Frequency = .daily

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your first habit")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("You can add more later.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("⭐")
                            .font(.title2)
                            .frame(width: 40)
                        TextField("", text: $name)
                            .placeholder(when: name.isEmpty) {
                                Text("e.g. Walk 10k steps")
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .foregroundStyle(.white)
                            .font(.body)
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HOW OFTEN?")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 14)
                        Picker("Frequency", selection: $frequency) {
                            ForEach(Frequency.allCases, id: \.self) { f in
                                Text(f.rawValue.capitalized).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button("Start My Streak →") {
                    createHabitAndFinish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
        }
    }

    private func createHabitAndFinish() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let habit = Habit(name: trimmed, emoji: "⭐", frequency: frequency)
        modelContext.insert(habit)
        try? modelContext.save()
        onComplete()
    }
}
```

The `placeholder(when:)` modifier is a small SwiftUI helper extension (2 lines) added to `View` in `FirstHabitStepView.swift`:

```swift
extension View {
    func placeholder<Content: View>(when condition: Bool, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .leading) { self; if condition { content() } }
    }
}
```

---

## ContentView changes

Add two lines to `ContentView`:

```swift
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
```

And on the root view:

```swift
.fullScreenCover(isPresented: .init(
    get: { !hasCompletedOnboarding },
    set: { if !$0 { hasCompletedOnboarding = true } }
)) {
    OnboardingView {
        hasCompletedOnboarding = true
    }
}
```

---

## Tests

All four new files are SwiftUI views — excluded from SPM. Existing 68 SPM tests must remain passing. Manual verification: delete app / reset `hasCompletedOnboarding` key in `UserDefaults` to re-trigger onboarding.

---

## Out of Scope (v1)

- Animated transitions between steps (SwiftUI default transitions are fine)
- "Skip" button on permissions or first-habit screen
- Suggested starter habits
- Re-showing onboarding after reset from Settings UI
- macOS-specific window sizing for the onboarding cover
