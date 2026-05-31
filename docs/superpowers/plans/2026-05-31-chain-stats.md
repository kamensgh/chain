# Chain Stats Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `StatsView` with a three-tab stats screen (Streaks, Summary, Calendar) showing per-habit streaks, completion rates, and a 30-day history grid.

**Architecture:** A new `StatsCalculator` pure domain type handles `periodsInWindow` and `completionRate` (testable in SPM). `StatsView` is a thin container with a segmented picker routing to `StreaksTabView`, `SummaryTabView`, and `CalendarTabView`. All tab views own their own `@Query`.

**Tech Stack:** SwiftUI, SwiftData (`@Query`), `StreakEntry` (already in `Chain/Domain/StreakCalculator.swift`), `StreakCalculator` (existing), `HabitScheduler` (existing), `Frequency.periodStart(for:)` (existing). SPM tests via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

---

## File map

| File | Action |
|---|---|
| `Chain/Domain/StatsCalculator.swift` | Create — `periodsInWindow` + `completionRate` |
| `ChainTests/StatsCalculatorTests.swift` | Create — SPM unit tests |
| `Chain/Views/Stats/StreaksTabView.swift` | Create — per-habit streak rows |
| `Chain/Views/Stats/SummaryTabView.swift` | Create — headline card + progress bars |
| `Chain/Views/Stats/CalendarTabView.swift` | Create — 30-day grid per habit |
| `Chain/Views/Stats/StatsView.swift` | Modify — replace placeholder |

`Package.swift` needs **no changes** — `Chain/Domain/` is already included in sources and `StatsCalculator.swift` has no SwiftData imports.

---

## Task 1: StatsCalculator domain type

**Files:**
- Create: `Chain/Domain/StatsCalculator.swift`
- Create: `ChainTests/StatsCalculatorTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ChainTests/StatsCalculatorTests.swift`:

```swift
import Testing
import Foundation
@testable import ChainDomain

struct StatsCalculatorTests {

    // Fixed anchor so tests don't break at midnight
    let anchor: Date = {
        var c = DateComponents()
        c.year = 2024; c.month = 1; c.day = 15
        return Calendar.current.date(from: c)!
    }()

    let cal = Calendar.current

    func day(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: anchor)!
    }

    func verified(_ daysAgo: Int) -> StreakEntry {
        StreakEntry(periodStart: day(daysAgo), status: .verified)
    }

    // periodsInWindow

    @Test func dailyWindowReturns30() {
        let periods = StatsCalculator.periodsInWindow(frequency: .daily, days: 30, today: anchor)
        #expect(periods.count == 30)
    }

    @Test func weeklyWindowReturnsAtMost5() {
        let periods = StatsCalculator.periodsInWindow(frequency: .weekly, days: 30, today: anchor)
        #expect(periods.count >= 4)
        #expect(periods.count <= 5)
    }

    @Test func periodsAreDistinct() {
        let periods = StatsCalculator.periodsInWindow(frequency: .weekly, days: 30, today: anchor)
        #expect(Set(periods).count == periods.count)
    }

    // completionRate

    @Test func emptyEntriesRateIsZero() {
        let rate = StatsCalculator.completionRate(entries: [], frequency: .daily, days: 7, today: anchor)
        #expect(rate == 0.0)
    }

    @Test func allVerifiedRateIsOne() {
        let entries = (0..<7).map { verified($0) }
        let rate = StatsCalculator.completionRate(entries: entries, frequency: .daily, days: 7, today: anchor)
        #expect(rate == 1.0)
    }

    @Test func halfVerifiedRateIsHalf() {
        // 4 verified out of 7 days
        let entries = [0, 2, 4, 6].map { verified($0) }
        let rate = StatsCalculator.completionRate(entries: entries, frequency: .daily, days: 7, today: anchor)
        #expect(abs(rate - 4.0 / 7.0) < 0.001)
    }

    @Test func outOfWindowEntriesIgnored() {
        let old = StreakEntry(periodStart: day(35), status: .verified)
        let rate = StatsCalculator.completionRate(entries: [old], frequency: .daily, days: 30, today: anchor)
        #expect(rate == 0.0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: compilation error — `StatsCalculator` not found.

- [ ] **Step 3: Implement StatsCalculator**

Create `Chain/Domain/StatsCalculator.swift`:

```swift
import Foundation

enum StatsCalculator {

    /// All unique period-start dates within the last `days` calendar days ending on `today`.
    static func periodsInWindow(
        frequency: Frequency,
        days: Int = 30,
        today: Date = .now
    ) -> [Date] {
        let cal = Calendar.current
        var seen = Set<Date>()
        var result: [Date] = []
        for offset in 0..<days {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let period = frequency.periodStart(for: d)
            if seen.insert(period).inserted {
                result.append(period)
            }
        }
        return result
    }

    /// Fraction of periods in the window covered by a verified entry.
    /// Pass entries as `habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }`.
    static func completionRate(
        entries: [StreakEntry],
        frequency: Frequency,
        days: Int = 30,
        today: Date = .now
    ) -> Double {
        let periods = periodsInWindow(frequency: frequency, days: days, today: today)
        guard !periods.isEmpty else { return 0.0 }
        let verified = periods.filter { period in
            entries.contains { $0.periodStart == period && $0.status == .verified }
        }.count
        return Double(verified) / Double(periods.count)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Chain/Domain/StatsCalculator.swift ChainTests/StatsCalculatorTests.swift
git commit -m "feat: add StatsCalculator with periodsInWindow and completionRate"
```

---

## Task 2: StreaksTabView

**Files:**
- Create: `Chain/Views/Stats/StreaksTabView.swift`

- [ ] **Step 1: Create StreaksTabView**

Create `Chain/Views/Stats/StreaksTabView.swift`:

```swift
import SwiftUI
import SwiftData

struct StreaksTabView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    var body: some View {
        if habits.isEmpty {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "target",
                description: Text("Go to Habits to add your first one.")
            )
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(habits) { habit in
                        StreakRowView(habit: habit)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct StreakRowView: View {
    let habit: Habit

    private var streakEntries: [StreakEntry] {
        habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
    }

    private var currentStreak: Int {
        StreakCalculator.current(
            entries: streakEntries,
            frequency: habit.frequency,
            today: Date(),
            gracePeriod: habit.gracePeriodEnabled
        )
    }

    private var longestStreak: Int {
        StreakCalculator.longest(entries: streakEntries, frequency: habit.frequency)
    }

    private var rate: Double {
        StatsCalculator.completionRate(entries: streakEntries, frequency: habit.frequency)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(habit.emoji)
                    .font(.system(size: 16))
            }

            Text(habit.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            Spacer()

            HStack(spacing: 12) {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Label("\(longestStreak)", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                Text("\(Int(rate * 100))%")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 2: Build check**

In Xcode or via `xcodegen` + build, verify there are no compile errors. There are no new SPM tests for this step — the domain logic is already tested.

```
xcodegen generate --spec project.yml
```

Open `Chain.xcodeproj` and build for macOS (`Cmd+B`). Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Stats/StreaksTabView.swift
git commit -m "feat: add StreaksTabView with current streak, longest streak, and 30-day rate"
```

---

## Task 3: SummaryTabView

**Files:**
- Create: `Chain/Views/Stats/SummaryTabView.swift`

- [ ] **Step 1: Create SummaryTabView**

Create `Chain/Views/Stats/SummaryTabView.swift`:

```swift
import SwiftUI
import SwiftData

struct SummaryTabView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    private var onTrackCount: Int {
        habits.filter { habit in
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
        }.count
    }

    private var globalRate: Double {
        guard !habits.isEmpty else { return 0.0 }
        let rates = habits.map { habit -> Double in
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return StatsCalculator.completionRate(entries: entries, frequency: habit.frequency)
        }
        return rates.reduce(0, +) / Double(rates.count)
    }

    var body: some View {
        if habits.isEmpty {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "target",
                description: Text("Go to Habits to add your first one.")
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    // Headline card
                    HStack(spacing: 0) {
                        statCell(value: "\(onTrackCount) / \(habits.count)", label: "On track today")
                        Divider().frame(height: 48)
                        statCell(value: "\(Int(globalRate * 100))%", label: "30-day avg")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    // Per-habit progress bars
                    VStack(spacing: 0) {
                        ForEach(habits) { habit in
                            HabitProgressRowView(habit: habit)
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HabitProgressRowView: View {
    let habit: Habit

    private var rate: Double {
        let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
        return StatsCalculator.completionRate(entries: entries, frequency: habit.frequency)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(habit.emoji).font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.subheadline)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * rate, height: 6)
                            .animation(.spring(response: 0.4), value: rate)
                    }
                }
                .frame(height: 6)
            }

            Text("\(Int(rate * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 2: Build check**

Build for macOS in Xcode. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Stats/SummaryTabView.swift
git commit -m "feat: add SummaryTabView with headline card and per-habit progress bars"
```

---

## Task 4: CalendarTabView

**Files:**
- Create: `Chain/Views/Stats/CalendarTabView.swift`

- [ ] **Step 1: Create CalendarTabView**

Create `Chain/Views/Stats/CalendarTabView.swift`:

```swift
import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    var body: some View {
        if habits.isEmpty {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "target",
                description: Text("Go to Habits to add your first one.")
            )
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(habits) { habit in
                        HabitCalendarView(habit: habit)
                    }
                }
                .padding()
            }
        }
    }
}

private struct HabitCalendarView: View {
    let habit: Habit
    private let cal = Calendar.current

    // 30 days oldest-first: index 0 is 29 days ago, index 29 is today
    private var days: [Date] {
        let today = cal.startOfDay(for: Date())
        return (0..<30).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func cellColor(for day: Date) -> Color {
        let period = habit.frequency.periodStart(for: day)
        // Only color cells that align with a period start for this frequency.
        // For daily habits, every day qualifies. For weekly, only week-start days.
        guard period == day else { return .clear }
        let isVerified = habit.entries.contains {
            $0.periodStart == period && $0.status == .verified
        }
        return isVerified ? Color.accentColor : Color.secondary.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(habit.emoji).font(.system(size: 16))
                Text(habit.name).font(.subheadline.bold())
            }

            let columns = Array(repeating: GridItem(.fixed(28), spacing: 4), count: 6)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cellColor(for: day))
                        .frame(width: 28, height: 28)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: Build check**

Build for macOS in Xcode. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Stats/CalendarTabView.swift
git commit -m "feat: add CalendarTabView with 30-day grid per habit"
```

---

## Task 5: StatsView container — wire tabs

**Files:**
- Modify: `Chain/Views/Stats/StatsView.swift`

- [ ] **Step 1: Replace placeholder StatsView**

Replace the entire contents of `Chain/Views/Stats/StatsView.swift` with:

```swift
import SwiftUI

enum StatsTab: String, CaseIterable, Identifiable {
    case streaks  = "Streaks"
    case summary  = "Summary"
    case calendar = "Calendar"
    var id: String { rawValue }
}

struct StatsView: View {
    @State private var selectedTab: StatsTab = .streaks

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(StatsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            switch selectedTab {
            case .streaks:  StreaksTabView()
            case .summary:  SummaryTabView()
            case .calendar: CalendarTabView()
            }
        }
        .navigationTitle("Stats")
    }
}
```

- [ ] **Step 2: Run full test suite**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: all tests pass (51+ passing, 0 failures).

- [ ] **Step 3: Build and verify in Xcode**

Build for macOS (`Cmd+B`). Navigate to the Stats tab in the sidebar. Verify:
- Segmented picker shows "Streaks / Summary / Calendar"
- Switching tabs renders the correct sub-view
- With no habits, each tab shows `ContentUnavailableView`
- With habits present, Streaks shows flame + star + percent; Summary shows the headline card and progress bars; Calendar shows a grid per habit

- [ ] **Step 4: Commit**

```bash
git add Chain/Views/Stats/StatsView.swift
git commit -m "feat: wire StatsView with segmented picker for Streaks, Summary, Calendar tabs"
```
