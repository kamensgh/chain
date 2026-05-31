# Chain macOS Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS-only `MenuBarExtra` scene showing the companion emoji as a live menu bar icon that opens a 280 pt popover for checking habits without switching to the main window.

**Architecture:** The verify + XP logic is extracted from `TodayView` into a shared `@MainActor enum HabitVerifier` so both the main window and the new menu bar rows share one write path. A `MenuBarExtra` scene is added to `ChainApp` alongside the `WindowGroup`, sharing the same `ModelContainer`. All menu bar views live under `Chain/Views/MenuBar/`.

**Tech Stack:** SwiftUI (`MenuBarExtra`, `.menuBarExtraStyle(.window)`, `@Query`, `@Environment(\.openWindow)`), SwiftData, AppKit (`NSApp.activate`), xcodegen

---

## File Map

**Create:**
- `Chain/Connectors/HabitVerifier.swift` — `@MainActor enum` with `verify(_:allHabits:context:companions:)` static method; excluded from SPM (imports SwiftData)
- `Chain/Views/MenuBar/MenuBarIconView.swift` — menu bar label: 18 pt companion emoji + 6 pt health dot; self-contained with `@Query`
- `Chain/Views/MenuBar/MenuBarHabitRowView.swift` — compact row: emoji + name + check/circle button; calls `HabitVerifier`
- `Chain/Views/MenuBar/MenuBarPopoverView.swift` — full popover: date header + `CompanionMenuBarView` + scrollable habit list + "Open Chain" footer

**Modify:**
- `Chain/ChainApp.swift` — add `id: "main"` to `WindowGroup`; add `#if os(macOS)` `MenuBarExtra` scene with `.menuBarExtraStyle(.window)` and `.modelContainer(container)`
- `Chain/Views/Today/TodayView.swift` — replace `verify(habit:)` + `applyDailyXP()` with `HabitVerifier.verify(_:allHabits:context:companions:)`
- `Package.swift` — add `"Connectors/HabitVerifier.swift"` to the `exclude` list

---

## Task 1: HabitVerifier + TodayView refactor

**Files:**
- Create: `Chain/Connectors/HabitVerifier.swift`
- Modify: `Package.swift`
- Modify: `Chain/Views/Today/TodayView.swift`

No automated unit tests — `HabitVerifier` imports SwiftData so it is excluded from the SPM target (same pattern as `ConnectorService`). The regression check is that all 51 existing tests still pass.

- [ ] **Step 1: Create HabitVerifier**

Create `Chain/Connectors/HabitVerifier.swift`:

```swift
import Foundation
import SwiftData

@MainActor
enum HabitVerifier {
    static func verify(_ habit: Habit, allHabits: [Habit], context: ModelContext, companions: [Companion]) {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
            guard existing.status != .verified else { return }
            existing.status = .verified
            existing.verifMethod = .manual
            existing.verifiedAt = Date()
        } else {
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = .verified
            entry.verifMethod = .manual
            entry.verifiedAt = Date()
            context.insert(entry)
        }
        applyDailyXP(allHabits: allHabits, companions: companions)
        try? context.save()
    }

    private static func applyDailyXP(allHabits: [Habit], companions: [Companion]) {
        guard let companion = companions.first else { return }
        if let last = companion.lastXPDate, Calendar.current.isDateInToday(last) { return }
        let needStates: [NeedState] = CompanionNeed.allCases.prefix(min(allHabits.count, 3)).map { need in
            let habit = allHabits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
        }
        let delta = CompanionEngine.xpDelta(needStates: needStates)
        if delta > 0 {
            companion.applyXP(delta)
            companion.lastXPDate = Date()
        }
    }
}
```

- [ ] **Step 2: Update Package.swift — add HabitVerifier to exclude list**

Open `Package.swift`. Find the `exclude` array. It currently ends with `"Connectors/ConnectorService.swift"`. Add `"Connectors/HabitVerifier.swift"` after it:

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
    "Connectors/HabitVerifier.swift"
],
```

- [ ] **Step 3: Verify SPM tests still pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5
```

Expected: `Test run with 51 tests passed.`

- [ ] **Step 4: Update TodayView to use HabitVerifier**

Replace the entire contents of `Chain/Views/Today/TodayView.swift` with the following (removes `verify(habit:)` and `applyDailyXP()`, delegates to `HabitVerifier`):

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]
    @Environment(\.modelContext) private var context

    private var doneCount: Int {
        habits.filter { habit in
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
        }.count
    }

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
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Today")
        .task { await verifyAll() }
        .refreshable { await verifyAll() }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning! ☀️"
        case 12..<17: return "Good afternoon! 🌤️"
        default:      return "Good evening! 🌙"
        }
    }

    private func verifyAll() async {
        await withTaskGroup(of: Void.self) { group in
            for habit in habits {
                guard habit.connectorType != .manual,
                      habit.connectorType != .screenshot else { continue }
                let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
                let alreadyDone = habit.entries.contains {
                    $0.periodStart == period && $0.status == .verified
                }
                guard !alreadyDone else { continue }
                group.addTask {
                    await ConnectorService.shared.verify(habit: habit, context: context)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Run all tests — verify nothing broke**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5
```

Expected: `Test run with 51 tests passed.`

- [ ] **Step 6: Commit**

```bash
git add Chain/Connectors/HabitVerifier.swift Package.swift Chain/Views/Today/TodayView.swift
git commit -m "refactor: extract HabitVerifier from TodayView for shared verify + XP logic"
```

---

## Task 2: MenuBarIconView

**Files:**
- Create: `Chain/Views/MenuBar/MenuBarIconView.swift`

The always-visible menu bar label. Uses `@Query` to fetch companion and habits directly — no parameters passed from outside since `MenuBarExtra` labels have no parent view to receive data from.

- [ ] **Step 1: Create MenuBarIconView**

Create `Chain/Views/MenuBar/MenuBarIconView.swift`:

```swift
import SwiftUI
import SwiftData

struct MenuBarIconView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]

    private var stage: PetStage {
        CompanionEngine.stage(xp: companions.first?.xp ?? 0)
    }

    private var characterEmoji: String {
        guard let companion = companions.first else { return "⛓️" }
        switch companion.companionType {
        case .pet:        return stage.petEmoji
        case .garden:     return stage.gardenEmoji
        case .trophyRoom: return "🏆"
        }
    }

    private var overallState: NeedState {
        guard !habits.isEmpty else { return .fed }
        let states: [NeedState] = CompanionNeed.allCases.prefix(min(habits.count, 3)).map { need in
            let habit = habits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
        }
        if states.contains(.sick)     { return .sick }
        if states.contains(.starving) { return .starving }
        if states.contains(.hungry)   { return .hungry }
        if states.contains(.peckish)  { return .peckish }
        return .fed
    }

    private var healthDotColor: Color {
        switch overallState {
        case .fed:      return .green
        case .peckish:  return .green.opacity(0.6)
        case .hungry:   return .yellow
        case .starving: return .orange
        case .sick:     return .gray
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(characterEmoji)
                .font(.system(size: 18))
                .colorMultiply(overallState == .sick ? Color(white: 0.6) : .white)
            Circle()
                .fill(healthDotColor)
                .frame(width: 6, height: 6)
        }
    }
}
```

- [ ] **Step 2: Run all tests — verify nothing broke**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5
```

Expected: `Test run with 51 tests passed.` (`Chain/Views/` is already excluded from SPM so this file isn't compiled by `swift test`.)

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/MenuBar/MenuBarIconView.swift
git commit -m "feat: add MenuBarIconView for companion emoji label"
```

---

## Task 3: MenuBarHabitRowView

**Files:**
- Create: `Chain/Views/MenuBar/MenuBarHabitRowView.swift`

Compact habit row used inside the popover. Receives `allHabits` and `companions` from the parent view so `HabitVerifier` has everything it needs.

- [ ] **Step 1: Create MenuBarHabitRowView**

Create `Chain/Views/MenuBar/MenuBarHabitRowView.swift`:

```swift
import SwiftUI
import SwiftData

struct MenuBarHabitRowView: View {
    let habit: Habit
    let allHabits: [Habit]
    let companions: [Companion]

    @Environment(\.modelContext) private var context

    private var isVerified: Bool {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(habit.emoji)
                .font(.body)
            Text(habit.name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            if isVerified {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Button {
                    HabitVerifier.verify(habit, allHabits: allHabits, context: context, companions: companions)
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 2: Run all tests — verify nothing broke**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5
```

Expected: `Test run with 51 tests passed.`

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/MenuBar/MenuBarHabitRowView.swift
git commit -m "feat: add MenuBarHabitRowView compact habit row for popover"
```

---

## Task 4: MenuBarPopoverView

**Files:**
- Create: `Chain/Views/MenuBar/MenuBarPopoverView.swift`

Full popover body. Fixed 280 pt width. Habit list scrolls up to 300 pt before clipping.

- [ ] **Step 1: Create MenuBarPopoverView**

Create `Chain/Views/MenuBar/MenuBarPopoverView.swift`:

```swift
import SwiftUI
import SwiftData

struct MenuBarPopoverView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Date + companion header
            VStack(spacing: 8) {
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let companion = companions.first {
                    CompanionMenuBarView(companion: companion, habits: habits)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)

            Divider()

            // Habit list
            if habits.isEmpty {
                Text("No habits yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(habits) { habit in
                            MenuBarHabitRowView(habit: habit, allHabits: habits, companions: companions)
                            if habit.id != habits.last?.id {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            Button("Open Chain") {
                openWindow(id: "main")
                #if os(macOS)
                NSApp.activate(ignoringOtherApps: true)
                #endif
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }
}
```

- [ ] **Step 2: Run all tests — verify nothing broke**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5
```

Expected: `Test run with 51 tests passed.`

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/MenuBar/MenuBarPopoverView.swift
git commit -m "feat: add MenuBarPopoverView with date, companion, habits, and Open Chain"
```

---

## Task 5: Wire MenuBarExtra in ChainApp + xcodegen

**Files:**
- Modify: `Chain/ChainApp.swift`

Add `id: "main"` to the `WindowGroup` (so `openWindow(id: "main")` works from the popover) and add the `MenuBarExtra` scene for macOS.

- [ ] **Step 1: Replace ChainApp.swift**

Replace the entire contents of `Chain/ChainApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Habit.self, HabitEntry.self, Companion.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .modelContainer(container)
                .task { await ensureCompanionExists() }
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarPopoverView()
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)
        #endif
    }

    @MainActor
    private func ensureCompanionExists() async {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Companion>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            context.insert(Companion())
            try? context.save()
        }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate 2>&1
```

Expected: `Loaded project at Chain.xcodeproj` (or similar success line). If xcodegen fails, read the error and fix the YAML.

- [ ] **Step 3: Run all SPM tests — verify nothing broke**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5
```

Expected: `Test run with 51 tests passed.`

- [ ] **Step 4: Commit**

```bash
git add Chain/ChainApp.swift Chain.xcodeproj
git commit -m "feat: wire MenuBarExtra scene with companion icon and habit popover"
```

---

## Self-Review

**Spec coverage:**
- ✅ Menu bar icon: companion emoji + health dot, 18 pt — `MenuBarIconView` (Task 2)
- ✅ Health dot reflects overall need state — `MenuBarIconView.overallState` + `healthDotColor` (Task 2)
- ✅ Grey tint when sick — `.colorMultiply` in `MenuBarIconView` (Task 2)
- ✅ Popover: date + `CompanionMenuBarView` + habit list — `MenuBarPopoverView` (Task 4)
- ✅ 280 pt fixed width — `.frame(width: 280)` in `MenuBarPopoverView` (Task 4)
- ✅ Scrollable habit list, max 300 pt — `ScrollView` + `.frame(maxHeight: 300)` (Task 4)
- ✅ Compact habit row: emoji + name + check button — `MenuBarHabitRowView` (Task 3)
- ✅ Verify from popover + XP awarded — `HabitVerifier` called from button action (Tasks 1+3)
- ✅ "Open Chain" via `openWindow(id: "main")` + `NSApp.activate` — `MenuBarPopoverView` footer (Task 4)
- ✅ Shared `ModelContainer` — `.modelContainer(container)` on `MenuBarExtra` (Task 5)
- ✅ `WindowGroup(id: "main")` — (Task 5)
- ✅ `.menuBarExtraStyle(.window)` — (Task 5)
- ✅ `#if os(macOS)` guard — (Task 5)
- ✅ `TodayView` refactored to use `HabitVerifier` — (Task 1)
- ✅ `Package.swift` excludes `HabitVerifier.swift` — (Task 1)

**Placeholder scan:** None. All steps have complete Swift code.

**Type consistency:**
- `HabitVerifier.verify(_ habit: Habit, allHabits: [Habit], context: ModelContext, companions: [Companion])` — defined Task 1, called in Task 1 (TodayView) and Task 3 (MenuBarHabitRowView) with matching signature ✅
- `MenuBarHabitRowView(habit: habit, allHabits: habits, companions: companions)` — defined Task 3, instantiated in Task 4 with matching labels ✅
- `CompanionNeed.allCases.prefix(min(habits.count, 3))` with `habits[need.rawValue]` — matches existing `applyDailyXP` pattern ✅
- `NeedState` cases (`fed`, `peckish`, `hungry`, `starving`, `sick`) — matches `CompanionMenuBarView.overallState` exactly ✅
- `PetStage` properties `petEmoji`, `gardenEmoji` — matches `CompanionMenuBarView.characterEmoji` ✅
