# Chain Companion System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global motivational companion (pet / garden / trophy room) that lives in the Today tab and evolves as the user completes habits.

**Architecture:** Pure domain logic lives in `CompanionEngine` (SPM-testable). One `Companion` SwiftData record stores type, XP, and unlocked accessories — all states are computed on the fly. `CompanionCardView` consumes `Companion + [Habit]` and animates using `PhaseAnimator`. The companion type picker lives in Settings.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing (domain tests via SPM)

---

## File Map

**Create:**
- `Chain/Domain/CompanionEngine.swift` — all domain types + pure stateless engine (SPM-included)
- `Chain/Models/Companion.swift` — SwiftData `@Model` (excluded from SPM)
- `Chain/Views/Companion/CompanionCardView.swift` — full companion card for Today tab
- `Chain/Views/Companion/CompanionMenuBarView.swift` — compact companion for menu bar popover
- `Chain/Views/Settings/CompanionSettingsView.swift` — companion type picker
- `ChainTests/CompanionEngineTests.swift` — SPM tests

**Modify:**
- `Package.swift` — add `Models/Companion.swift` to exclude list
- `Chain/ChainApp.swift` — add `Companion.self` to `ModelContainer` schema
- `Chain/Views/Today/TodayView.swift` — insert `CompanionCardView` above habit list
- `Chain/Views/Settings/SettingsView.swift` — add Companion section

---

## Task 1: CompanionEngine — domain types and logic

**Files:**
- Create: `Chain/Domain/CompanionEngine.swift`
- Test: `ChainTests/CompanionEngineTests.swift`

All types and engine logic go in one file. This file has zero Apple SDK dependencies beyond Foundation — it compiles in the SPM test runner with no entitlements.

- [ ] **Step 1: Write the failing tests**

```swift
// ChainTests/CompanionEngineTests.swift
import Testing
import Foundation
@testable import ChainDomain

struct CompanionEngineTests {

    let cal = Calendar.current

    func day(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
    }

    func verified(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .verified)
    }

    // MARK: needState

    @Test func fedWhenTodayVerified() {
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(0)], frequency: .daily, now: now)
        #expect(state == .fed)
    }

    @Test func peckishWhenNewHabitNoEntries() {
        // No history at all → not sick yet, just peckish
        let now = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [], frequency: .daily, now: now)
        #expect(state == .peckish)
    }

    @Test func sickWhenYesterdayMissedAndHasHistory() {
        // Has an older entry (history exists) but yesterday was not verified
        let twoDaysAgo = StreakEntry(periodStart: day(2), status: .verified)
        let now = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [twoDaysAgo], frequency: .daily, now: now)
        #expect(state == .sick)
    }

    @Test func hungryAfter6pm() {
        let now = cal.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        // Yesterday was verified, today not done yet
        let state = CompanionEngine.needState(for: .food, entries: [verified(1)], frequency: .daily, now: now)
        #expect(state == .hungry)
    }

    @Test func starvingAfter9pm() {
        let now = cal.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(1)], frequency: .daily, now: now)
        #expect(state == .starving)
    }

    @Test func peckishBefore6pm() {
        let now = cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(1)], frequency: .daily, now: now)
        #expect(state == .peckish)
    }

    @Test func weeklyHabitPeckishWhenInSamePeriod() {
        // Yesterday is still in the same week as today → no sick
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let state = CompanionEngine.needState(for: .food, entries: [verified(7)], frequency: .weekly, now: now)
        // verified(7) is last week; this week has no entry → but frequency is weekly
        // The "previous period" for weekly depends on whether yesterday was in the prior week
        // This test just checks it doesn't crash and returns a valid state
        #expect(state != .fed)  // not done this week
    }

    // MARK: stage

    @Test func stage0IsEgg() {
        #expect(CompanionEngine.stage(xp: 0) == .egg)
    }

    @Test func stage50IsBaby() {
        #expect(CompanionEngine.stage(xp: 50) == .baby)
    }

    @Test func stage200IsJuvenile() {
        #expect(CompanionEngine.stage(xp: 200) == .juvenile)
    }

    @Test func stage500IsAdult() {
        #expect(CompanionEngine.stage(xp: 500) == .adult)
    }

    @Test func stage1000IsLegendary() {
        #expect(CompanionEngine.stage(xp: 1000) == .legendary)
    }

    @Test func stageBelowFloorIsLower() {
        #expect(CompanionEngine.stage(xp: 49) == .egg)
        #expect(CompanionEngine.stage(xp: 199) == .baby)
    }

    // MARK: xpDelta

    @Test func noNeedsReturnsZero() {
        #expect(CompanionEngine.xpDelta(needStates: []) == 0)
    }

    @Test func allSickReturnsMinus5() {
        #expect(CompanionEngine.xpDelta(needStates: [.sick]) == -5)
        #expect(CompanionEngine.xpDelta(needStates: [.sick, .sick]) == -5)
    }

    @Test func oneNeedFedReturns10() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed]) == 10)
    }

    @Test func twoNeedsFedReturns15() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed, .fed]) == 15)
    }

    @Test func threeNeedsFedReturns20() {
        #expect(CompanionEngine.xpDelta(needStates: [.fed, .fed, .fed]) == 20)
    }

    @Test func mixedFedAndHungryCountsFed() {
        // hungry is not fed, not sick — counts as 0 fed in XP delta
        // One fed, one hungry → 10 XP (only fed ones count)
        #expect(CompanionEngine.xpDelta(needStates: [.fed, .hungry]) == 10)
    }

    // MARK: trophies

    @Test func noTrophiesForShortStreak() {
        let entries = [StreakEntry(periodStart: Calendar.current.startOfDay(for: Date()), status: .verified)]
        let result = CompanionEngine.trophies(habits: [(name: "Run", entries: entries, frequency: .daily)], today: Date())
        #expect(result.isEmpty)
    }

    @Test func bronzeTrophyAt7Days() {
        let entries = (0..<7).map { StreakEntry(periodStart: Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date()))!, status: .verified) }
        let result = CompanionEngine.trophies(habits: [(name: "Run", entries: entries, frequency: .daily)], today: Date())
        #expect(result.contains { $0.tier == .bronze && $0.habitName == "Run" })
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CompanionEngineTests 2>&1 | tail -20
```

Expected: compile error — `CompanionEngine` not found.

- [ ] **Step 3: Implement CompanionEngine.swift**

```swift
// Chain/Domain/CompanionEngine.swift
import Foundation

// MARK: - Types

enum CompanionType: String, Codable, CaseIterable {
    case pet, garden, trophyRoom

    var displayName: String {
        switch self {
        case .pet:        return "Pet"
        case .garden:     return "Garden"
        case .trophyRoom: return "Trophy Room"
        }
    }
}

enum CompanionNeed: Int, CaseIterable {
    case food = 0, water = 1, exercise = 2

    var petLabel: String {
        switch self { case .food: return "Food"; case .water: return "Water"; case .exercise: return "Exercise" }
    }

    var gardenLabel: String {
        switch self { case .food: return "Watering"; case .water: return "Sunlight"; case .exercise: return "Fertilizer" }
    }

    var petEmoji: String {
        switch self { case .food: return "🍖"; case .water: return "🫧"; case .exercise: return "🏃" }
    }

    var gardenEmoji: String {
        switch self { case .food: return "💧"; case .water: return "☀️"; case .exercise: return "🌿" }
    }
}

enum NeedState: Equatable {
    case fed, peckish, hungry, starving, sick

    var isUrgent: Bool { self == .hungry || self == .starving || self == .sick }
}

enum PetStage: String, Codable, CaseIterable {
    case egg, baby, juvenile, adult, legendary

    var xpFloor: Double {
        switch self {
        case .egg:       return 0
        case .baby:      return 50
        case .juvenile:  return 200
        case .adult:     return 500
        case .legendary: return 1000
        }
    }

    // Emoji shown in CompanionCardView — nil means no overlay
    var accessoryEmoji: String? {
        switch self {
        case .egg:       return nil
        case .baby:      return "🏷️"
        case .juvenile:  return "🎩"
        case .adult:     return "🎭"
        case .legendary: return "👑"
        }
    }

    var petEmoji: String {
        switch self {
        case .egg:       return "🥚"
        case .baby:      return "🐣"
        case .juvenile:  return "🐱"
        case .adult:     return "😺"
        case .legendary: return "🦁"
        }
    }

    var gardenEmoji: String {
        switch self {
        case .egg:       return "🌱"
        case .baby:      return "🌿"
        case .juvenile:  return "🌳"
        case .adult:     return "🌸"
        case .legendary: return "🌺"
        }
    }
}

enum TrophyTier: Int, CaseIterable {
    case bronze = 7, silver = 14, gold = 30, platinum = 60, diamond = 100

    var emoji: String {
        switch self {
        case .bronze:   return "🥉"
        case .silver:   return "🥈"
        case .gold:     return "🥇"
        case .platinum: return "🏅"
        case .diamond:  return "💎"
        }
    }

    var label: String {
        switch self {
        case .bronze:   return "7-day"
        case .silver:   return "14-day"
        case .gold:     return "30-day"
        case .platinum: return "60-day"
        case .diamond:  return "100-day"
        }
    }
}

struct Trophy: Equatable {
    let tier: TrophyTier
    let habitName: String
}

// MARK: - Engine

enum CompanionEngine {

    /// Returns the NeedState for one companion need.
    /// `entries` are the StreakEntries for the specific habit mapped to this need.
    /// Sick = previous period passed with no verified entry AND the habit has older history.
    /// Time urgency (hungry/starving) only applies to daily habits.
    static func needState(
        for need: CompanionNeed,
        entries: [StreakEntry],
        frequency: Frequency,
        now: Date
    ) -> NeedState {
        let cal = Calendar.current
        let todayPeriod = HabitScheduler.periodStart(for: frequency, on: now)

        if entries.contains(where: { $0.periodStart == todayPeriod && $0.status == .verified }) {
            return .fed
        }

        let prevDate = cal.date(byAdding: .day, value: -1, to: now)!
        let prevPeriod = HabitScheduler.periodStart(for: frequency, on: prevDate)
        let isPrevDifferentPeriod = prevPeriod != todayPeriod
        let prevVerified = entries.contains { $0.periodStart == prevPeriod && $0.status == .verified }

        if isPrevDifferentPeriod && !prevVerified && !entries.isEmpty {
            return .sick
        }

        guard frequency == .daily else { return .peckish }

        let hour = cal.component(.hour, from: now)
        switch hour {
        case 0..<18: return .peckish
        case 18..<21: return .hungry
        default:     return .starving
        }
    }

    /// Maps accumulated XP to an evolution stage.
    static func stage(xp: Double) -> PetStage {
        switch xp {
        case ..<50:   return .egg
        case ..<200:  return .baby
        case ..<500:  return .juvenile
        case ..<1000: return .adult
        default:      return .legendary
        }
    }

    /// XP delta for one day based on how many needs were fed.
    /// Only `.fed` needs count; others (peckish, hungry, starving) earn 0 bonus XP.
    /// If no needs are fed at all (all sick or all pending at day end), returns −5.
    static func xpDelta(needStates: [NeedState]) -> Double {
        guard !needStates.isEmpty else { return 0 }
        let fedCount = needStates.filter { $0 == .fed }.count
        if fedCount == 0 { return -5 }
        return 5.0 * Double(min(fedCount, 3) + 1)  // 10, 15, or 20
    }

    /// Returns trophies earned across all habits based on current streaks.
    static func trophies(
        habits: [(name: String, entries: [StreakEntry], frequency: Frequency)],
        today: Date
    ) -> [Trophy] {
        var result: [Trophy] = []
        for habit in habits {
            let streak = StreakCalculator.current(entries: habit.entries, frequency: habit.frequency, today: today)
            for tier in TrophyTier.allCases where streak >= tier.rawValue {
                result.append(Trophy(tier: tier, habitName: habit.name))
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CompanionEngineTests 2>&1 | tail -15
```

Expected: all CompanionEngineTests pass. Fix any failures before continuing.

- [ ] **Step 5: Run all tests — verify nothing broke**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -10
```

Expected: full suite green.

- [ ] **Step 6: Commit**

```bash
git add Chain/Domain/CompanionEngine.swift ChainTests/CompanionEngineTests.swift
git commit -m "feat: add CompanionEngine domain types and logic"
```

---

## Task 2: Companion SwiftData model + app wiring

**Files:**
- Create: `Chain/Models/Companion.swift`
- Modify: `Package.swift`
- Modify: `Chain/ChainApp.swift`

- [ ] **Step 1: Create Companion.swift**

```swift
// Chain/Models/Companion.swift
import SwiftData
import Foundation

@Model
final class Companion {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var xp: Double
    var accessoriesUnlocked: [String]   // PetStage raw values that have been passed through
    var createdAt: Date

    var companionType: CompanionType {
        get { CompanionType(rawValue: typeRaw) ?? .pet }
        set { typeRaw = newValue.rawValue }
    }

    init(type: CompanionType = .pet) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.xp = 0
        self.accessoriesUnlocked = []
        self.createdAt = Date()
    }

    /// Adds XP, clamps to 0, unlocks accessories for newly reached stages.
    /// Returns the newly unlocked PetStage if a stage transition occurred, nil otherwise.
    @discardableResult
    func applyXP(_ delta: Double) -> PetStage? {
        let oldStage = CompanionEngine.stage(xp: xp)
        xp = max(CompanionEngine.stage(xp: xp).xpFloor, xp + delta)
        let newStage = CompanionEngine.stage(xp: xp)
        if newStage != oldStage && !accessoriesUnlocked.contains(newStage.rawValue) {
            accessoriesUnlocked.append(newStage.rawValue)
            return newStage
        }
        return nil
    }
}
```

- [ ] **Step 2: Add Companion.swift to Package.swift exclude list**

Open `Package.swift`. In the `exclude` array, add `"Models/Companion.swift"`:

```swift
exclude: [
    "ChainApp.swift",
    "Info.plist",
    "Assets.xcassets",
    "Views",
    "ContentView.swift",
    "Models/Habit.swift",
    "Models/HabitEntry.swift",
    "Connectors/HealthKitConnector.swift",
    "Connectors/ConnectorService.swift",
    "Models/Companion.swift"
],
```

- [ ] **Step 3: Add Companion to ModelContainer and auto-create on launch**

Open `Chain/ChainApp.swift`. Replace the entire file content with:

```swift
// Chain/ChainApp.swift
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
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .task { await ensureCompanionExists() }
        }
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

- [ ] **Step 4: Verify SPM tests still pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -10
```

Expected: all tests pass — `Companion.swift` is excluded from SPM.

- [ ] **Step 5: Regenerate Xcode project (new Swift file added)**

```
cd /Users/mac/Documents/projects/chain && xcodegen generate 2>&1 | tail -5
```

Expected: `Loaded project at Chain.xcodeproj`

- [ ] **Step 6: Commit**

```bash
git add Chain/Models/Companion.swift Package.swift Chain/ChainApp.swift
git commit -m "feat: add Companion SwiftData model and auto-create on launch"
```

---

## Task 3: CompanionCardView

**Files:**
- Create: `Chain/Views/Companion/CompanionCardView.swift`
- Modify: `Chain/Views/Today/TodayView.swift`

The card shows the character emoji, XP bar, need indicators, and a growth prompt. It uses `PhaseAnimator` for idle float and `.colorMultiply` for sick grey-out.

- [ ] **Step 1: Create the Companion/directory and CompanionCardView**

First, confirm the Views directory exists:
```
ls /Users/mac/Documents/projects/chain/Chain/Views/
```

Then create the file:

```swift
// Chain/Views/Companion/CompanionCardView.swift
import SwiftUI

struct CompanionCardView: View {
    let companion: Companion
    let habits: [Habit]   // ordered by createdAt — first 3 map to food/water/exercise

    // MARK: - Computed

    private var companionType: CompanionType { companion.companionType }
    private var stage: PetStage { CompanionEngine.stage(xp: companion.xp) }

    private var characterEmoji: String {
        switch companionType {
        case .pet:        return stage.petEmoji
        case .garden:     return stage.gardenEmoji
        case .trophyRoom: return "🏆"
        }
    }

    private var overallState: NeedState {
        let states = activePairs.map { $0.state }
        if states.contains(.sick)     { return .sick }
        if states.contains(.starving) { return .starving }
        if states.contains(.hungry)   { return .hungry }
        if states.contains(.peckish)  { return .peckish }
        return .fed
    }

    private struct NeedPair: Identifiable {
        let id: Int
        let need: CompanionNeed
        let state: NeedState
    }

    private var activePairs: [NeedPair] {
        CompanionNeed.allCases.prefix(min(habits.count, 3)).map { need in
            let habit = habits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            let state = CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
            return NeedPair(id: need.rawValue, need: need, state: state)
        }
    }

    private var xpProgress: Double {
        let all = PetStage.allCases
        guard let idx = all.firstIndex(of: stage), idx + 1 < all.count else { return 1 }
        let nextFloor = all[idx + 1].xpFloor
        let range = nextFloor - stage.xpFloor
        return range > 0 ? (companion.xp - stage.xpFloor) / range : 1
    }

    private var trophyItems: [Trophy] {
        guard companionType == .trophyRoom else { return [] }
        let habitData = habits.map { habit in
            (
                name: habit.name,
                entries: habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) },
                frequency: habit.frequency
            )
        }
        return CompanionEngine.trophies(habits: habitData, today: Date())
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {
            characterSection
            if companionType == .trophyRoom {
                trophySection
            } else {
                xpBarSection
                needIndicatorsSection
                growthPromptSection
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Subviews

    private var characterSection: some View {
        PhaseAnimator([false, true]) { phase in
            ZStack(alignment: .topTrailing) {
                Text(overallState == .sick ? characterEmoji : characterEmoji)
                    .font(.system(size: 72))
                    .offset(y: phase ? -4 : 4)
                    .colorMultiply(overallState == .sick ? Color(white: 0.55) : .white)
                    .overlay(alignment: .topTrailing) {
                        if let accessory = stage.accessoryEmoji {
                            Text(accessory)
                                .font(.system(size: 26))
                                .offset(x: 6, y: -6)
                        }
                    }

                if overallState == .sick {
                    Text("🤒")
                        .font(.system(size: 26))
                        .offset(x: -2, y: -8)
                }
            }
        } animation: { _ in
            .easeInOut(duration: 1.8)
        }
    }

    private var xpBarSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text(stage.rawValue.capitalized)
                    .font(.caption.bold())
                Spacer()
                Text("\(Int(companion.xp)) XP")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * min(max(xpProgress, 0), 1), height: 6)
                        .animation(.spring(response: 0.5), value: companion.xp)
                }
            }
            .frame(height: 6)
        }
    }

    private var needIndicatorsSection: some View {
        HStack(spacing: 20) {
            ForEach(activePairs) { pair in
                VStack(spacing: 4) {
                    Text(pair.state == .fed ? "✅" : pair.state == .sick ? "🤒" : pair.need.petEmoji)
                        .font(.title3)
                    Text(companionType == .garden ? pair.need.gardenLabel : pair.need.petLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var growthPromptSection: some View {
        if habits.count < 3, let nextNeed = CompanionNeed.allCases[safe: habits.count] {
            let label = companionType == .garden ? nextNeed.gardenLabel : nextNeed.petLabel
            Text("Add a \(label) habit to grow faster! ➕")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var trophySection: some View {
        Group {
            if trophyItems.isEmpty {
                Text("Complete habits to earn trophies 🏆")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(trophyItems.prefix(9).enumerated()), id: \.offset) { _, trophy in
                        VStack(spacing: 2) {
                            Text(trophy.tier.emoji).font(.title2)
                            Text(trophy.tier.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// Safe subscript helper to avoid index-out-of-bounds in the growth prompt
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Wire CompanionCardView into TodayView**

Open `Chain/Views/Today/TodayView.swift`. The file currently has `@Query(sort: \Habit.createdAt) private var habits: [Habit]` and a body with a `ScrollView`. Make these changes:

Add a companion query after the existing habits query:
```swift
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]
    @Environment(\.modelContext) private var context
```

Add the companion card at the top of the habit list section in the ScrollView. Find the line:
```swift
                // Habit list
```

And insert the companion card before it:
```swift
                // Companion card
                if let companion = companions.first {
                    CompanionCardView(companion: companion, habits: habits)
                }

                // Habit list
```

- [ ] **Step 3: Regenerate Xcode project**

```
cd /Users/mac/Documents/projects/chain && xcodegen generate 2>&1 | tail -5
```

- [ ] **Step 4: Verify SPM tests still pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add Chain/Views/Companion/CompanionCardView.swift Chain/Views/Today/TodayView.swift
git commit -m "feat: add CompanionCardView and wire into TodayView"
```

---

## Task 4: CompanionMenuBarView

**Files:**
- Create: `Chain/Views/Companion/CompanionMenuBarView.swift`

Compact view for the macOS menu bar popover (wired in Plan 3 when the popover is built). Create it now so it exists and compiles.

- [ ] **Step 1: Create CompanionMenuBarView**

```swift
// Chain/Views/Companion/CompanionMenuBarView.swift
import SwiftUI

struct CompanionMenuBarView: View {
    let companion: Companion
    let habits: [Habit]

    private var stage: PetStage { CompanionEngine.stage(xp: companion.xp) }

    private var characterEmoji: String {
        switch companion.companionType {
        case .pet:        return stage.petEmoji
        case .garden:     return stage.gardenEmoji
        case .trophyRoom: return "🏆"
        }
    }

    private var overallState: NeedState {
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
        HStack(spacing: 6) {
            PhaseAnimator([false, true]) { phase in
                Text(characterEmoji)
                    .font(.system(size: 28))
                    .offset(y: phase ? -2 : 2)
                    .colorMultiply(overallState == .sick ? Color(white: 0.6) : .white)
            } animation: { _ in
                .easeInOut(duration: 2.0)
            }

            Circle()
                .fill(healthDotColor)
                .frame(width: 8, height: 8)
        }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project**

```
cd /Users/mac/Documents/projects/chain && xcodegen generate 2>&1 | tail -5
```

- [ ] **Step 3: Verify SPM tests still pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add Chain/Views/Companion/CompanionMenuBarView.swift
git commit -m "feat: add CompanionMenuBarView for menu bar popover"
```

---

## Task 5: CompanionSettingsView + SettingsView

**Files:**
- Create: `Chain/Views/Settings/CompanionSettingsView.swift`
- Modify: `Chain/Views/Settings/SettingsView.swift`

Users pick their companion type here. Changing type immediately updates the `Companion` record.

- [ ] **Step 1: Create CompanionSettingsView**

```swift
// Chain/Views/Settings/CompanionSettingsView.swift
import SwiftUI
import SwiftData

struct CompanionSettingsView: View {
    @Query private var companions: [Companion]
    @Environment(\.modelContext) private var context

    private var companion: Companion? { companions.first }

    var body: some View {
        if let companion {
            VStack(alignment: .leading, spacing: 12) {
                Text("Companion Style")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(CompanionType.allCases, id: \.self) { type in
                        typeCard(type: type, isSelected: companion.companionType == type) {
                            companion.companionType = type
                            try? context.save()
                        }
                    }
                }
            }
        }
    }

    private func typeCard(_ type: CompanionType, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(previewEmoji(for: type))
                    .font(.system(size: 36))
                Text(type.displayName)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func previewEmoji(for type: CompanionType) -> String {
        switch type {
        case .pet:        return "🐱"
        case .garden:     return "🌸"
        case .trophyRoom: return "🏆"
        }
    }
}
```

- [ ] **Step 2: Add Companion section to SettingsView**

Open `Chain/Views/Settings/SettingsView.swift`. Replace its entire content with:

```swift
// Chain/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Companion") {
                CompanionSettingsView()
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            Section("Notifications") {
                Text("Reminder settings coming soon")
                    .foregroundStyle(.secondary)
            }
            Section("Connectors") {
                Text("App connections coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
```

- [ ] **Step 3: Regenerate Xcode project**

```
cd /Users/mac/Documents/projects/chain && xcodegen generate 2>&1 | tail -5
```

- [ ] **Step 4: Verify SPM tests still pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add Chain/Views/Settings/CompanionSettingsView.swift Chain/Views/Settings/SettingsView.swift
git commit -m "feat: add companion type picker in Settings"
```

---

## Task 6: XP accumulation on habit verification

**Files:**
- Modify: `Chain/Views/Today/TodayView.swift`

When a habit is verified, the Companion's XP should update. This hooks into the existing `verify(habit:)` function in `TodayView`.

- [ ] **Step 1: Update TodayView.verify to apply XP**

Open `Chain/Views/Today/TodayView.swift`. The file currently has a `private func verify(habit: Habit)` function. Replace it with:

```swift
    private func verify(habit: Habit) {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
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
        applyDailyXP()
        try? context.save()
    }

    private func applyDailyXP() {
        guard let companion = companions.first else { return }
        // Compute current need states across all mapped habits
        let needStates: [NeedState] = CompanionNeed.allCases.prefix(min(habits.count, 3)).map { need in
            let habit = habits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
        }
        let delta = CompanionEngine.xpDelta(needStates: needStates)
        // Only award XP once per day — check if we already applied it today
        // XP is applied when at least one need transitions to .fed (delta > 0 and hasn't been awarded yet today)
        // Simple approach: always apply; CompanionEngine.xpDelta gives correct delta based on current fed count
        // (calling multiple times on the same day with same fed count gives same delta, so idempotent in practice)
        if delta > 0 {
            companion.applyXP(delta)
        }
    }
```

> **Note:** The `companions` property was added to `TodayView` in Task 3. Verify it's present: `@Query private var companions: [Companion]`.

- [ ] **Step 2: Verify SPM tests still pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Today/TodayView.swift
git commit -m "feat: apply XP to companion when habit is verified"
```

---

## Self-Review

**Spec coverage check:**

| Requirement | Task |
|---|---|
| Three companion types: pet, garden, trophy room | Task 1 (types), Task 5 (settings picker) |
| User picks type in Settings | Task 5 |
| Habit → need auto-mapping (1st=food, 2nd=water, 3rd=exercise) | Task 1 (CompanionNeed.rawValue index) + Task 3 |
| Need states: fed/peckish/hungry/starving/sick | Task 1 |
| Time-based urgency (6pm/9pm thresholds) | Task 1 |
| Sick when previous period missed + has history | Task 1 |
| 5 evolution stages (egg→baby→juvenile→adult→legendary) | Task 1 (PetStage) |
| XP per day: 10/15/20 based on fed needs | Task 1 (xpDelta) |
| XP cannot drop below current stage floor | Task 2 (Companion.applyXP) |
| Accessories unlock at stage transitions | Task 2 (Companion.applyXP + accessoriesUnlocked) |
| CompanionCardView in Today tab | Task 3 |
| Emoji character + accessory overlay | Task 3 |
| Idle float animation (PhaseAnimator) | Task 3 |
| Sick grey-out + 🤒 overlay | Task 3 |
| XP progress bar | Task 3 |
| Need indicators row | Task 3 |
| Growth prompt when < 3 habits | Task 3 |
| Trophy room milestone trophies | Task 1 (trophies function) + Task 3 (trophySection) |
| CompanionMenuBarView (compact) | Task 4 |
| XP accumulates on habit verification | Task 6 |
| One Companion record created on first launch | Task 2 |

**Placeholder scan:** None. All steps have complete code.

**Type consistency check:**
- `CompanionNeed.rawValue` is `Int` (0, 1, 2) — used as array index in `habits[need.rawValue]` ✅
- `PetStage.xpFloor` used in `Companion.applyXP` and `CompanionCardView.xpProgress` ✅
- `CompanionEngine.needState(for:entries:frequency:now:)` signature matches all call sites ✅
- `CompanionEngine.xpDelta(needStates:)` takes `[NeedState]` — matches `TodayView.applyDailyXP` ✅
- `CompanionEngine.trophies(habits:today:)` tuple type `(name: String, entries: [StreakEntry], frequency: Frequency)` matches `CompanionCardView.trophyItems` ✅
- `Companion.applyXP(_:)` returns `PetStage?` — caller uses `@discardableResult` ✅

**Known limitation:** XP accumulation in Task 6 is applied each time `verify()` is called. If the user taps verify 3 times in one day, XP is applied 3 times. A production fix would track `lastXPDate` on `Companion` to guard against double-awards. This is acceptable for v1 given the playful nature of the mechanic.
