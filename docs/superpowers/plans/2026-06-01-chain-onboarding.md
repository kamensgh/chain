# Chain Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 3-screen first-launch onboarding flow (Welcome → Permissions → First Habit) that shows once via `.fullScreenCover` gated on a `@AppStorage` flag.

**Architecture:** Four new SwiftUI views live in `Chain/Views/Onboarding/`. `OnboardingView` is the container that switches between steps using an `OnboardingStep` enum. `ContentView` gates the cover with `@AppStorage("hasCompletedOnboarding")`. After the user creates their first habit, the flag flips to `true` and the cover dismisses.

**Tech Stack:** SwiftUI `.fullScreenCover`, `@AppStorage`, SwiftData `modelContext.insert`, `HKHealthStore.requestAuthorization`, `UNUserNotificationCenter`.

---

## Context

Chain habit streak app — SwiftUI multiplatform macOS 14 + iOS 17, SwiftData, SPM `ChainDomain` target.

Run tests with:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected baseline: **68 tests pass**.

All new files are SwiftUI views — excluded from SPM automatically (SPM sources are `["Domain", "Connectors", "Models"]`; `Views/` is not in that list). No new SPM tests to write. Verify no regressions by running the 68 existing tests after each task.

`Chain/Views/Onboarding/` is a **new directory** under `Chain/Views/`. Run `xcodegen generate` after Task 1 to pick it up in the Xcode project.

---

## File map

| File | Action |
|---|---|
| `Chain/Views/Onboarding/OnboardingView.swift` | Create — container with `OnboardingStep` enum and step switching |
| `Chain/Views/Onboarding/WelcomeStepView.swift` | Create — Screen 1: centered logo + tagline + "Get Started" |
| `Chain/Views/Onboarding/PermissionsStepView.swift` | Create — Screen 2: HealthKit + notifications cards + "Continue" |
| `Chain/Views/Onboarding/FirstHabitStepView.swift` | Create — Screen 3: name field + frequency picker + "Start My Streak" |
| `Chain/ContentView.swift` | Modify — add `@AppStorage` flag + `.fullScreenCover` |

---

## Task 1: OnboardingView container + WelcomeStepView

**Files:**
- Create: `Chain/Views/Onboarding/OnboardingView.swift`
- Create: `Chain/Views/Onboarding/WelcomeStepView.swift`

- [ ] **Step 1: Create OnboardingView.swift**

Create `Chain/Views/Onboarding/OnboardingView.swift` with the following complete contents:

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

- [ ] **Step 2: Create WelcomeStepView.swift**

Create `Chain/Views/Onboarding/WelcomeStepView.swift` with the following complete contents:

```swift
import SwiftUI

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

- [ ] **Step 3: Run xcodegen**

`Chain/Views/Onboarding/` is a new directory — regenerate the Xcode project so it gets picked up:

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: `Chain.xcodeproj` regenerated with no errors.

- [ ] **Step 4: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Chain/Views/Onboarding/OnboardingView.swift Chain/Views/Onboarding/WelcomeStepView.swift Chain.xcodeproj
git commit -m "feat: add OnboardingView container and WelcomeStepView"
```

---

## Task 2: PermissionsStepView

**Files:**
- Create: `Chain/Views/Onboarding/PermissionsStepView.swift`

- [ ] **Step 1: Create PermissionsStepView.swift**

Create `Chain/Views/Onboarding/PermissionsStepView.swift` with the following complete contents:

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
        if HKHealthStore.isHealthDataAvailable() {
            let readTypes: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.workoutType()
            ]
            try? await HKHealthStore().requestAuthorization(toShare: [], read: readTypes)
        }
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

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Onboarding/PermissionsStepView.swift
git commit -m "feat: add PermissionsStepView with HealthKit and notification requests"
```

---

## Task 3: FirstHabitStepView

**Files:**
- Create: `Chain/Views/Onboarding/FirstHabitStepView.swift`

- [ ] **Step 1: Create FirstHabitStepView.swift**

Create `Chain/Views/Onboarding/FirstHabitStepView.swift` with the following complete contents:

```swift
import SwiftUI
import SwiftData

struct FirstHabitStepView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var frequency: Frequency = .daily

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

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
                        ZStack(alignment: .leading) {
                            if name.isEmpty {
                                Text("e.g. Walk 10k steps")
                                    .foregroundStyle(.white.opacity(0.3))
                                    .font(.body)
                            }
                            TextField("", text: $name)
                                .foregroundStyle(.white)
                                .font(.body)
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HOW OFTEN?")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 2)
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
                .disabled(trimmedName.isEmpty)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
        }
    }

    private func createHabitAndFinish() {
        guard !trimmedName.isEmpty else { return }
        let habit = Habit(name: trimmedName, emoji: "⭐", frequency: frequency)
        modelContext.insert(habit)
        try? modelContext.save()
        onComplete()
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
git add Chain/Views/Onboarding/FirstHabitStepView.swift
git commit -m "feat: add FirstHabitStepView with name field and frequency picker"
```

---

## Task 4: Wire ContentView

**Files:**
- Modify: `Chain/ContentView.swift`

Add the `@AppStorage` gate and `.fullScreenCover` presenting `OnboardingView` to both the macOS and iOS branches of `ContentView`.

- [ ] **Step 1: Replace ContentView.swift**

Replace the entire contents of `Chain/ContentView.swift` with:

```swift
import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List {
                NavigationLink(destination: TodayView()) {
                    Label("Today", systemImage: "house.fill")
                }
                NavigationLink(destination: HabitsListView()) {
                    Label("Habits", systemImage: "target")
                }
                NavigationLink(destination: StatsView()) {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("⛓️ Chain")
        } detail: {
            TodayView()
        }
        .fullScreenCover(isPresented: .init(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        #else
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "house.fill") }
            NavigationStack { HabitsListView() }
                .tabItem { Label("Habits", systemImage: "target") }
            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .fullScreenCover(isPresented: .init(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        #endif
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
git add Chain/ContentView.swift
git commit -m "feat: gate ContentView behind onboarding fullScreenCover"
```
