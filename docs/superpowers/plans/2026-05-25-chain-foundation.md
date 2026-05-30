# Chain Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working Chain app (macOS + iOS) where users can create habits and manually check them off with accurate streak tracking.

**Architecture:** SwiftUI multiplatform app with SwiftData for persistence. Pure-logic domain layer (StreakCalculator, HabitScheduler) is fully TDD'd and decoupled from SwiftData. Views are thin, delegating logic to domain types.

**Tech Stack:** Swift 5.9+, Xcode 16+, SwiftUI, SwiftData, Swift Testing framework (`import Testing`), iOS 17+ / macOS 14+

**Scope note:** This is Plan 1 of 3. Plan 2 adds HealthKit/MCP/screenshot connectors. Plan 3 adds Stats screen, menu bar popover, notifications, and CloudKit sync.

---

## File Structure

```
Chain/
├── Chain.xcodeproj
├── Chain/                              # Shared (iOS + macOS)
│   ├── ChainApp.swift                  # @main, ModelContainer setup
│   ├── ContentView.swift               # Root: TabView (iOS) / NavigationSplitView (Mac)
│   ├── Models/
│   │   ├── Frequency.swift             # enum: daily/weekly/monthly + periodStart logic
│   │   ├── GoalConfig.swift            # Codable struct: unit + targetValue
│   │   ├── ConnectorType.swift         # enum: manual/healthKitSteps/etc
│   │   ├── EntryStatus.swift           # enum: pending/verified/skipped + VerifMethod
│   │   ├── Habit.swift                 # @Model SwiftData class
│   │   └── HabitEntry.swift            # @Model SwiftData class
│   ├── Domain/
│   │   ├── StreakCalculator.swift      # Pure logic: current + longest streak
│   │   └── HabitScheduler.swift       # Pure logic: periodStart, isDue, entryForToday
│   ├── Connectors/
│   │   ├── HabitConnector.swift        # Protocol + VerificationResult
│   │   └── ManualConnector.swift       # Instant-verify connector
│   └── Views/
│       ├── Today/
│       │   ├── TodayView.swift
│       │   └── HabitRowView.swift
│       ├── Habits/
│       │   ├── HabitsListView.swift
│       │   └── AddHabitView.swift
│       ├── Stats/
│       │   └── StatsView.swift         # Stub for Plan 3
│       └── Settings/
│           └── SettingsView.swift      # Stub for Plan 3
└── ChainTests/
    ├── StreakCalculatorTests.swift
    ├── HabitSchedulerTests.swift
    └── ManualConnectorTests.swift
```

---

### Task 1: Xcode project setup

**Files:**
- Create: `Chain.xcodeproj` (via Xcode UI)
- Modify: `Chain/ChainApp.swift`

- [ ] **Step 1: Create the Xcode project**

  Open Xcode → File → New → Project → **Multiplatform → App**
  - Product Name: `Chain`
  - Bundle ID: `com.yourname.chain`
  - Language: Swift, Interface: SwiftUI
  - Uncheck "Use Core Data", check "Include Tests"
  - Save to `/Users/mac/Documents/projects/chain`

- [ ] **Step 2: Configure targets**

  In project settings → Signing & Capabilities:
  - Add capability: **iCloud** (check CloudKit)
  - Add capability: **HealthKit**
  - Deployment targets: **iOS 17.0, macOS 14.0**

- [ ] **Step 3: Replace ChainApp.swift**

```swift
// Chain/ChainApp.swift
import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Habit.self, HabitEntry.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

- [ ] **Step 4: Delete the auto-generated ContentView.swift** (we will create our own in Task 7)

- [ ] **Step 5: Build to confirm empty project compiles**

  Press ⌘+B. Expected: Build Succeeded (ignore missing ContentView error until Task 7).

- [ ] **Step 6: Commit**

```bash
git add Chain.xcodeproj Chain/ChainApp.swift
git commit -m "feat: create Chain Xcode multiplatform project"
```

---

### Task 2: Enums and value types

**Files:**
- Create: `Chain/Models/Frequency.swift`
- Create: `Chain/Models/GoalConfig.swift`
- Create: `Chain/Models/ConnectorType.swift`
- Create: `Chain/Models/EntryStatus.swift`

- [ ] **Step 1: Create Chain/Models/Frequency.swift**

```swift
import Foundation

enum Frequency: String, Codable, CaseIterable {
    case daily, weekly, monthly

    func periodStart(for date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:   return cal.startOfDay(for: date)
        case .weekly:  return cal.dateInterval(of: .weekOfYear, for: date)!.start
        case .monthly: return cal.dateInterval(of: .month, for: date)!.start
        }
    }
}
```

- [ ] **Step 2: Create Chain/Models/GoalConfig.swift**

```swift
import Foundation

enum GoalUnit: String, Codable, CaseIterable {
    case boolean, steps, minutes, custom
}

struct GoalConfig: Codable {
    var unit: GoalUnit
    var targetValue: Double
    var customLabel: String

    static let boolean = GoalConfig(unit: .boolean, targetValue: 0, customLabel: "")

    static func steps(_ count: Double) -> GoalConfig {
        GoalConfig(unit: .steps, targetValue: count, customLabel: "")
    }

    static func minutes(_ count: Double) -> GoalConfig {
        GoalConfig(unit: .minutes, targetValue: count, customLabel: "")
    }
}
```

- [ ] **Step 3: Create Chain/Models/ConnectorType.swift**

```swift
import Foundation

enum ConnectorType: String, Codable, CaseIterable {
    case manual
    case healthKitSteps
    case healthKitWorkout
    case healthKitSleep
    case screenshot
    case mcp

    var displayName: String {
        switch self {
        case .manual:          return "Manual check-in"
        case .healthKitSteps:  return "Apple Health – Steps"
        case .healthKitWorkout: return "Apple Health – Workout"
        case .healthKitSleep:  return "Apple Health – Sleep"
        case .screenshot:      return "Screenshot proof"
        case .mcp:             return "MCP server"
        }
    }
}
```

- [ ] **Step 4: Create Chain/Models/EntryStatus.swift**

```swift
import Foundation

enum EntryStatus: String, Codable {
    case pending, verified, skipped
}

enum VerifMethod: String, Codable {
    case auto, screenshot, manual
}
```

- [ ] **Step 5: Build (⌘+B) — must compile cleanly**

- [ ] **Step 6: Commit**

```bash
git add Chain/Models/
git commit -m "feat: add core enums Frequency, GoalConfig, ConnectorType, EntryStatus"
```

---

### Task 3: SwiftData models

**Files:**
- Create: `Chain/Models/Habit.swift`
- Create: `Chain/Models/HabitEntry.swift`

- [ ] **Step 1: Create Chain/Models/Habit.swift**

  `GoalConfig` and `ConnectorType` are stored as JSON `Data` / raw strings because SwiftData requires persistable types. Computed properties expose the typed values.

```swift
import SwiftData
import Foundation

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var frequencyRaw: String
    var goalConfigData: Data
    var connectorTypeRaw: String
    var connectorEndpoint: String?      // MCP URL, stored in model (non-sensitive)
    var reminderTime: Date?
    var gracePeriodEnabled: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var entries: [HabitEntry] = []

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var goalConfig: GoalConfig {
        get { (try? JSONDecoder().decode(GoalConfig.self, from: goalConfigData)) ?? .boolean }
        set { goalConfigData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var connectorType: ConnectorType {
        get { ConnectorType(rawValue: connectorTypeRaw) ?? .manual }
        set { connectorTypeRaw = newValue.rawValue }
    }

    init(name: String, emoji: String, frequency: Frequency = .daily, goalConfig: GoalConfig = .boolean) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = ""
        self.frequencyRaw = frequency.rawValue
        self.goalConfigData = (try? JSONEncoder().encode(goalConfig)) ?? Data()
        self.connectorTypeRaw = ConnectorType.manual.rawValue
        self.gracePeriodEnabled = false
        self.createdAt = Date()
    }
}
```

- [ ] **Step 2: Create Chain/Models/HabitEntry.swift**

```swift
import SwiftData
import Foundation

@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var periodStart: Date
    var statusRaw: String
    var verifMethodRaw: String
    var value: Double?
    var screenshotPath: String?
    var verifiedAt: Date?
    var habit: Habit?

    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var verifMethod: VerifMethod {
        get { VerifMethod(rawValue: verifMethodRaw) ?? .manual }
        set { verifMethodRaw = newValue.rawValue }
    }

    init(habit: Habit, periodStart: Date) {
        self.id = UUID()
        self.periodStart = periodStart
        self.statusRaw = EntryStatus.pending.rawValue
        self.verifMethodRaw = VerifMethod.manual.rawValue
        self.habit = habit
    }
}
```

- [ ] **Step 3: Build (⌘+B) — must compile cleanly**

- [ ] **Step 4: Commit**

```bash
git add Chain/Models/Habit.swift Chain/Models/HabitEntry.swift
git commit -m "feat: add SwiftData models Habit and HabitEntry"
```

---

### Task 4: StreakCalculator (TDD)

**Files:**
- Create: `ChainTests/StreakCalculatorTests.swift`
- Create: `Chain/Domain/StreakCalculator.swift`

`StreakCalculator` works on `StreakEntry` — a plain struct with no SwiftData dependency — so it's fast to test in isolation.

- [ ] **Step 1: Create ChainTests/StreakCalculatorTests.swift**

```swift
import Testing
import Foundation
@testable import Chain

struct StreakCalculatorTests {

    let cal = Calendar.current

    func day(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
    }

    func verified(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .verified)
    }

    func skipped(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .skipped)
    }

    @Test func emptyEntriesReturnsZero() {
        #expect(StreakCalculator.current(entries: [], frequency: .daily, today: Date()) == 0)
    }

    @Test func todayAloneIsStreakOf1() {
        #expect(StreakCalculator.current(entries: [verified(0)], frequency: .daily, today: Date()) == 1)
    }

    @Test func threeDaysConsecutiveIsStreakOf3() {
        let entries = [verified(0), verified(1), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date()) == 3)
    }

    @Test func missedDayBreaksStreak() {
        // days 0 and 2 verified, day 1 missing → streak is 1
        let entries = [verified(0), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date()) == 1)
    }

    @Test func longestSpansAcrossGap() {
        // streak of 3 (days 2,1,0), then a gap, then streak of 1 (day 10)
        let entries = [verified(0), verified(1), verified(2), verified(10)]
        #expect(StreakCalculator.longest(entries: entries, frequency: .daily) == 3)
    }

    @Test func gracePeriodCountsSkippedDay() {
        // day 2 verified, day 1 skipped (grace), day 0 verified → streak = 3
        let entries = [verified(0), skipped(1), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date(), gracePeriod: true) == 3)
    }

    @Test func gracePeriodOffSkippedBreaksStreak() {
        let entries = [verified(0), skipped(1), verified(2)]
        #expect(StreakCalculator.current(entries: entries, frequency: .daily, today: Date(), gracePeriod: false) == 1)
    }
}
```

- [ ] **Step 2: Run — expect compile error (StreakEntry and StreakCalculator not defined)**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep -E "error:|Build FAILED"
```

Expected: `error: cannot find type 'StreakCalculator' in scope`

- [ ] **Step 3: Create Chain/Domain/StreakCalculator.swift**

```swift
import Foundation

struct StreakEntry {
    let periodStart: Date
    let status: EntryStatus
}

enum StreakCalculator {

    static func current(
        entries: [StreakEntry],
        frequency: Frequency,
        today: Date,
        gracePeriod: Bool = false
    ) -> Int {
        let cal = Calendar.current
        let relevant = entries.filter {
            gracePeriod ? $0.status != .pending : $0.status == .verified
        }.sorted { $0.periodStart > $1.periodStart }

        guard !relevant.isEmpty else { return 0 }

        var streak = 0
        var cursor = frequency.periodStart(for: today)

        for entry in relevant {
            let entryPeriod = frequency.periodStart(for: entry.periodStart)
            guard entryPeriod == cursor else { break }
            streak += 1
            // Move cursor back one period by stepping into the previous period
            let dayBefore = cal.date(byAdding: .day, value: -1, to: cursor)!
            cursor = frequency.periodStart(for: dayBefore)
        }

        return streak
    }

    static func longest(entries: [StreakEntry], frequency: Frequency) -> Int {
        let cal = Calendar.current
        let sorted = entries
            .filter { $0.status == .verified }
            .sorted { $0.periodStart < $1.periodStart }

        guard !sorted.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        var prevPeriod: Date?

        for entry in sorted {
            let period = frequency.periodStart(for: entry.periodStart)
            if let prev = prevPeriod {
                let dayBefore = cal.date(byAdding: .day, value: -1, to: period)!
                let expectedPrev = frequency.periodStart(for: dayBefore)
                current = (expectedPrev == prev) ? current + 1 : 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prevPeriod = period
        }

        return longest
    }
}
```

- [ ] **Step 4: Run tests — all StreakCalculatorTests must pass**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: 7 tests passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add Chain/Domain/StreakCalculator.swift ChainTests/StreakCalculatorTests.swift
git commit -m "feat: add StreakCalculator with TDD (current + longest streak)"
```

---

### Task 5: HabitScheduler (TDD)

**Files:**
- Create: `ChainTests/HabitSchedulerTests.swift`
- Create: `Chain/Domain/HabitScheduler.swift`

- [ ] **Step 1: Create ChainTests/HabitSchedulerTests.swift**

```swift
import Testing
import Foundation
@testable import Chain

struct HabitSchedulerTests {

    let cal = Calendar.current

    @Test func dailyPeriodStartIsStartOfDay() {
        let date = Date()
        #expect(HabitScheduler.periodStart(for: .daily, on: date) == cal.startOfDay(for: date))
    }

    @Test func weeklyPeriodStartIsStartOfWeek() {
        let date = Date()
        #expect(HabitScheduler.periodStart(for: .weekly, on: date) == cal.dateInterval(of: .weekOfYear, for: date)!.start)
    }

    @Test func monthlyPeriodStartIsStartOfMonth() {
        let date = Date()
        #expect(HabitScheduler.periodStart(for: .monthly, on: date) == cal.dateInterval(of: .month, for: date)!.start)
    }

    @Test func isDueTrueWhenNoEntries() {
        #expect(HabitScheduler.isDue(frequency: .daily, entries: [], on: Date()) == true)
    }

    @Test func isDueFalseWhenVerifiedEntryExists() {
        let today = cal.startOfDay(for: Date())
        let entry = StreakEntry(periodStart: today, status: .verified)
        #expect(HabitScheduler.isDue(frequency: .daily, entries: [entry], on: Date()) == false)
    }

    @Test func isDueTrueWhenEntryIsPending() {
        let today = cal.startOfDay(for: Date())
        let entry = StreakEntry(periodStart: today, status: .pending)
        #expect(HabitScheduler.isDue(frequency: .daily, entries: [entry], on: Date()) == true)
    }

    @Test func entryForTodayReturnsCorrectEntry() {
        let today = cal.startOfDay(for: Date())
        let entry = StreakEntry(periodStart: today, status: .verified)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let old = StreakEntry(periodStart: yesterday, status: .verified)
        #expect(HabitScheduler.entry(for: .daily, entries: [entry, old], on: Date())?.periodStart == today)
    }
}
```

- [ ] **Step 2: Run — expect compile error**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep -E "error:|Build FAILED"
```

Expected: `error: cannot find 'HabitScheduler' in scope`

- [ ] **Step 3: Create Chain/Domain/HabitScheduler.swift**

```swift
import Foundation

enum HabitScheduler {

    static func periodStart(for frequency: Frequency, on date: Date) -> Date {
        frequency.periodStart(for: date)
    }

    static func isDue(frequency: Frequency, entries: [StreakEntry], on date: Date) -> Bool {
        let period = periodStart(for: frequency, on: date)
        return !entries.contains { $0.periodStart == period && $0.status == .verified }
    }

    static func entry(for frequency: Frequency, entries: [StreakEntry], on date: Date) -> StreakEntry? {
        let period = periodStart(for: frequency, on: date)
        return entries.first { $0.periodStart == period }
    }
}
```

- [ ] **Step 4: Run all tests — must pass**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: all StreakCalculatorTests + HabitSchedulerTests pass (0 failed).

- [ ] **Step 5: Commit**

```bash
git add Chain/Domain/HabitScheduler.swift ChainTests/HabitSchedulerTests.swift
git commit -m "feat: add HabitScheduler with TDD"
```

---

### Task 6: HabitConnector protocol + ManualConnector (TDD)

**Files:**
- Create: `Chain/Connectors/HabitConnector.swift`
- Create: `Chain/Connectors/ManualConnector.swift`
- Create: `ChainTests/ManualConnectorTests.swift`

- [ ] **Step 1: Create ChainTests/ManualConnectorTests.swift**

```swift
import Testing
@testable import Chain

struct ManualConnectorTests {

    @Test func verifyReturnsVerifiedStatus() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.status == .verified)
    }

    @Test func verifyReturnsManualMethod() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.verifMethod == .manual)
    }

    @Test func verifyReturnsNilValue() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.value == nil)
    }

    @Test func sourceLabelIsManual() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.sourceLabel == "Manual")
    }
}
```

- [ ] **Step 2: Run — expect compile error**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep "error:"
```

- [ ] **Step 3: Create Chain/Connectors/HabitConnector.swift**

```swift
import Foundation

struct VerificationResult {
    let status: EntryStatus
    let verifMethod: VerifMethod
    let value: Double?
    let sourceLabel: String
}

protocol HabitConnector {
    func verify(goalConfig: GoalConfig) async throws -> VerificationResult
}
```

- [ ] **Step 4: Create Chain/Connectors/ManualConnector.swift**

```swift
import Foundation

struct ManualConnector: HabitConnector {
    func verify(goalConfig: GoalConfig) async throws -> VerificationResult {
        VerificationResult(status: .verified, verifMethod: .manual, value: nil, sourceLabel: "Manual")
    }
}
```

- [ ] **Step 5: Run all tests — must pass**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: all 18 tests pass (StreakCalculator + HabitScheduler + ManualConnector).

- [ ] **Step 6: Commit**

```bash
git add Chain/Connectors/ ChainTests/ManualConnectorTests.swift
git commit -m "feat: add HabitConnector protocol and ManualConnector"
```

---

### Task 7: Root navigation + stub views

**Files:**
- Create: `Chain/ContentView.swift`
- Create: `Chain/Views/Stats/StatsView.swift`
- Create: `Chain/Views/Settings/SettingsView.swift`

These stub views satisfy ContentView's references. Stats and Settings are fleshed out in Plans 3 and 2 respectively.

- [ ] **Step 1: Create Chain/Views/Stats/StatsView.swift**

```swift
import SwiftUI

struct StatsView: View {
    var body: some View {
        ContentUnavailableView("Stats coming soon", systemImage: "chart.bar.fill",
            description: Text("Streak history and completion rates — coming in a future update."))
            .navigationTitle("Stats")
    }
}
```

- [ ] **Step 2: Create Chain/Views/Settings/SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
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

- [ ] **Step 3: Create Chain/ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
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
        #endif
    }
}
```

- [ ] **Step 4: Build (⌘+B) — will fail on missing TodayView and HabitsListView (expected, fixed in Tasks 8–9)**

- [ ] **Step 5: Commit (do not commit yet — wait until Tasks 8 and 9 compile)**

---

### Task 8: TodayView + HabitRowView

**Files:**
- Create: `Chain/Views/Today/TodayView.swift`
- Create: `Chain/Views/Today/HabitRowView.swift`

- [ ] **Step 1: Create Chain/Views/Today/HabitRowView.swift**

```swift
import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    let onVerify: () -> Void

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

            // Name + status
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(isVerified ? .green : .secondary)
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
            } else {
                Button(action: onVerify) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
}
```

- [ ] **Step 2: Create Chain/Views/Today/TodayView.swift**

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
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
                            verify(habit: habit)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Today")
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning! ☀️"
        case 12..<17: return "Good afternoon! 🌤️"
        default:      return "Good evening! 🌙"
        }
    }

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
        try? context.save()
    }
}
```

- [ ] **Step 3: Build (⌘+B) — TodayView and HabitRowView must compile**

- [ ] **Step 4: Commit (still hold — add HabitsListView first)**

---

### Task 9: HabitsListView + AddHabitView

**Files:**
- Create: `Chain/Views/Habits/HabitsListView.swift`
- Create: `Chain/Views/Habits/AddHabitView.swift`

- [ ] **Step 1: Create Chain/Views/Habits/HabitsListView.swift**

```swift
import SwiftUI
import SwiftData

struct HabitsListView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(habits) { habit in
                NavigationLink(destination: AddHabitView(habit: habit)) {
                    HStack(spacing: 10) {
                        Text(habit.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name).font(.subheadline.weight(.medium))
                            Text(habit.frequency.rawValue.capitalized + " · " + habit.connectorType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddHabitView() }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { habits[$0] }.forEach { context.delete($0) }
        try? context.save()
    }
}
```

- [ ] **Step 2: Create Chain/Views/Habits/AddHabitView.swift**

```swift
import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var habit: Habit? = nil         // nil = create new, non-nil = edit existing

    @State private var name = ""
    @State private var emoji = "⭐"
    @State private var frequency: Frequency = .daily
    @State private var goalUnit: GoalUnit = .boolean
    @State private var goalTarget: Double = 0
    @State private var connectorType: ConnectorType = .manual
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var gracePeriodEnabled = false

    var body: some View {
        Form {
            Section("Name & Icon") {
                HStack(spacing: 12) {
                    TextField("🙂", text: $emoji)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                    TextField("Habit name", text: $name)
                }
            }

            Section("Schedule") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(Frequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue.capitalized).tag(freq)
                    }
                }
            }

            Section("Goal") {
                Picker("Type", selection: $goalUnit) {
                    Text("Done / Not done").tag(GoalUnit.boolean)
                    Text("Steps").tag(GoalUnit.steps)
                    Text("Minutes").tag(GoalUnit.minutes)
                    Text("Custom").tag(GoalUnit.custom)
                }
                .pickerStyle(.segmented)
                if goalUnit != .boolean {
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField("0", value: $goalTarget, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(goalUnit.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Verification") {
                Picker("Connect to", selection: $connectorType) {
                    ForEach(ConnectorType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Reminder") {
                Toggle("Daily reminder", isOn: $reminderEnabled)
                if reminderEnabled {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }

            Section("Options") {
                Toggle("Grace period", isOn: $gracePeriodEnabled)
                if gracePeriodEnabled {
                    Text("One missed day won't break your streak.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: loadExisting)
    }

    private func loadExisting() {
        guard let h = habit else { return }
        name = h.name
        emoji = h.emoji
        frequency = h.frequency
        goalUnit = h.goalConfig.unit
        goalTarget = h.goalConfig.targetValue
        connectorType = h.connectorType
        gracePeriodEnabled = h.gracePeriodEnabled
        if let t = h.reminderTime {
            reminderEnabled = true
            reminderTime = t
        }
    }

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
        } else {
            let h = Habit(name: trimmedName, emoji: emoji, frequency: frequency, goalConfig: goal)
            h.connectorType = connectorType
            h.gracePeriodEnabled = gracePeriodEnabled
            h.reminderTime = reminderEnabled ? reminderTime : nil
            context.insert(h)
        }
        try? context.save()
        dismiss()
    }
}
```

- [ ] **Step 3: Build (⌘+B) — full project must compile cleanly**

- [ ] **Step 4: Run on iPhone 16 Simulator**

  Press ▶ with iPhone 16 destination. Verify:
  - Today tab shows "No habits yet" empty state
  - Habits tab shows empty list with + button
  - Tapping + opens the Add Habit sheet
  - Fill in name "Walk 10k steps", emoji "🚶", frequency Daily, tap Save
  - Habit appears in the Habits list
  - Habit appears in Today tab
  - Tapping the circle marks it verified — checkmark fills, streak badge shows 🔥 1
  - Streak count says "Done ✓"

- [ ] **Step 5: Run on Mac**

  Switch destination to My Mac. Verify the sidebar appears with Today selected as default, and the same create/verify flow works.

- [ ] **Step 6: Run all tests — must still pass**

```bash
xcodebuild test -scheme Chain -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: 18 tests, 0 failed.

- [ ] **Step 7: Commit everything**

```bash
git add Chain/Views/ Chain/ContentView.swift
git commit -m "feat: add all views — TodayView, HabitRowView, HabitsListView, AddHabitView, stubs for Stats and Settings"
```

---

## What's next

**Plan 2 — Connectors:** HealthKit (steps, workout, sleep), screenshot proof, MCP generic client, GitHub/Notion specific connectors, ConnectorConfig in Keychain.

**Plan 3 — Polish:** Stats screen (streak calendar), macOS menu bar popover (`.ultraThinMaterial`), local notifications (reminders, streak-at-risk, milestones), CloudKit sync.
