# Chain Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three WidgetKit widgets — a small home-screen overview ring, an interactive medium habit checklist, and lock-screen circular/inline accessories — sharing the main app's SwiftData store via an App Group.

**Architecture:** A new `ChainWidget` app-extension target is added to `project.yml`. Both the app and widget use `ModelContainerFactory.make(inAppGroup: true)` which stores SwiftData in a shared App Group container (`group.com.chain.app`). The `VerifyHabitIntent` (`AppIntents`) writes to the same container and reloads all timelines. The widget target sources `Chain/Models`, `Chain/Domain`, and `Chain/Persistence` directly so model and domain types are shared without a separate framework.

**Tech Stack:** WidgetKit, SwiftData, AppIntents, SwiftUI, xcodegen (`project.yml`), iOS 17.

---

## Context

Chain habit streak app — SwiftUI multiplatform macOS 14 + iOS 17, SwiftData, xcodegen for project generation, SPM `ChainDomain` target for pure domain tests.

Run tests with:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected baseline: **68 tests pass**.

All new files are in `ChainWidget/` (a new top-level directory alongside `Chain/`) or are SwiftUI/WidgetKit views — excluded from SPM automatically. No new SPM tests to write. Verify no regressions by running the 68 existing tests after each task.

`ChainWidget/` is a **new top-level directory**. Run `xcodegen generate` in Task 1 to pick it up.

---

## File map

| File | Action |
|---|---|
| `Chain/Persistence/ModelContainerFactory.swift` | Modify — add `inAppGroup: Bool = false` param |
| `Chain/ChainApp.swift` | Modify — pass `inAppGroup: true` |
| `Chain/Chain.entitlements` | Modify — add App Group |
| `project.yml` | Modify — add `ChainWidget` target, embed in `Chain` |
| `ChainWidget/ChainWidget.entitlements` | Create — App Group for widget target |
| `ChainWidget/WidgetEntry.swift` | Create — `HabitSummary` + `TimelineEntry` snapshot |
| `ChainWidget/Provider.swift` | Create — `TimelineProvider` reading shared SwiftData |
| `ChainWidget/VerifyHabitIntent.swift` | Create — `AppIntent` that verifies a habit |
| `ChainWidget/SmallWidgetView.swift` | Create — progress ring view + `ChainSmallWidget` |
| `ChainWidget/MediumWidgetView.swift` | Create — interactive checklist + `ChainMediumWidget` |
| `ChainWidget/LockScreenWidgetView.swift` | Create — accessoryCircular/accessoryInline + `ChainLockScreenWidget` |
| `ChainWidget/ChainWidgetBundle.swift` | Create — `@main` entry wiring all three kinds |
| `Chain/Views/Today/TodayView.swift` | Modify — call `WidgetCenter.shared.reloadAllTimelines()` after verify |

---

## Task 1: App Group infrastructure

**Files:**
- Modify: `Chain/Persistence/ModelContainerFactory.swift`
- Modify: `Chain/ChainApp.swift`
- Modify: `Chain/Chain.entitlements`
- Create: `ChainWidget/ChainWidget.entitlements`
- Modify: `project.yml`

- [ ] **Step 1: Update ModelContainerFactory.swift**

Replace the entire contents of `Chain/Persistence/ModelContainerFactory.swift` with:

```swift
import SwiftData

enum ModelContainerFactory {

    static func make(inAppGroup: Bool = false) throws -> ModelContainer {
        let schema = Schema([Habit.self, HabitEntry.self, Companion.self])
        #if CLOUDKIT_SYNC
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.chain.app")
        )
        #else
        let config: ModelConfiguration
        if inAppGroup {
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier("group.com.chain.app")
            )
        } else {
            config = ModelConfiguration(schema: schema)
        }
        #endif
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2: Update ChainApp.swift**

In `Chain/ChainApp.swift`, change the one line inside the `do` block from:
```swift
container = try ModelContainerFactory.make()
```
to:
```swift
container = try ModelContainerFactory.make(inAppGroup: true)
```

- [ ] **Step 3: Add App Group to Chain.entitlements**

Replace the entire contents of `Chain/Chain.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.background-delivery</key>
    <true/>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.chain.app</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.chain.app</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Create ChainWidget/ChainWidget.entitlements**

Create `ChainWidget/ChainWidget.entitlements` with the following contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.chain.app</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 5: Update project.yml**

Replace the entire contents of `project.yml` with:

```yaml
name: Chain
options:
  bundleIdPrefix: com.chain
  deploymentTarget:
    iOS: "17.0"
    macOS: "14.0"
  xcodeVersion: "16.0"
  groupSortPosition: none

targets:
  Chain:
    type: application
    platform: [iOS, macOS]
    sources:
      - path: Chain
    dependencies:
      - target: ChainWidget
        embed: true
    info:
      path: Chain/Info.plist
      properties:
        CFBundleDisplayName: Chain
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
        UILaunchScreen:
          UIColorName: ""
        NSHealthShareUsageDescription: "Chain reads health data to automatically verify your fitness habits."
        NSPhotoLibraryUsageDescription: "Chain saves a screenshot as proof that you completed your habit."
        NSCameraUsageDescription: "Chain lets you take a photo as proof that you completed your habit."
    settings:
      base:
        SWIFT_VERSION: "5.9"
        DEVELOPMENT_TEAM: ""
        CODE_SIGN_STYLE: Automatic
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        CODE_SIGN_ENTITLEMENTS: Chain/Chain.entitlements

  ChainWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: ChainWidget
      - path: Chain/Models
      - path: Chain/Domain
      - path: Chain/Persistence
    settings:
      base:
        SWIFT_VERSION: "5.9"
        CODE_SIGN_ENTITLEMENTS: ChainWidget/ChainWidget.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.chain.app.widget
    info:
      path: ChainWidget/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension

  ChainTests_iOS_Runner:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ChainTests
    dependencies:
      - target: Chain_iOS
    settings:
      base:
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGNING_REQUIRED: NO

  ChainTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: ChainTests
    dependencies:
      - target: Chain_macOS
    settings:
      base:
        SWIFT_VERSION: "5.9"
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGNING_REQUIRED: NO
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Chain.app/Contents/MacOS/Chain"
        BUNDLE_LOADER: "$(TEST_HOST)"

schemes:
  Chain_macOS:
    build:
      targets:
        Chain_macOS: all
        ChainTests: [test]
    test:
      targets:
        - ChainTests
```

- [ ] **Step 6: Run xcodegen**

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: `Chain.xcodeproj` regenerated with no errors. The project now contains a `ChainWidget` extension target.

- [ ] **Step 7: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 8: Commit**

```bash
git add Chain/Persistence/ModelContainerFactory.swift Chain/ChainApp.swift Chain/Chain.entitlements ChainWidget/ChainWidget.entitlements project.yml Chain.xcodeproj
git commit -m "feat: add App Group shared store and ChainWidget extension target"
```

---

## Task 2: WidgetEntry + Provider (data layer)

**Files:**
- Create: `ChainWidget/WidgetEntry.swift`
- Create: `ChainWidget/Provider.swift`

- [ ] **Step 1: Create WidgetEntry.swift**

Create `ChainWidget/WidgetEntry.swift` with the following complete contents:

```swift
import WidgetKit
import Foundation

struct HabitSummary: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isVerifiedToday: Bool
    let currentStreak: Int
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let habits: [HabitSummary]
    let bestStreak: Int
    let verifiedCount: Int
    let totalCount: Int
}

extension WidgetEntry {
    static let placeholder = WidgetEntry(
        date: .now,
        habits: [
            HabitSummary(id: "1", name: "Walk 10k steps", emoji: "🏃", isVerifiedToday: true, currentStreak: 7),
            HabitSummary(id: "2", name: "Read 20 min", emoji: "📚", isVerifiedToday: false, currentStreak: 3),
            HabitSummary(id: "3", name: "Drink water", emoji: "💧", isVerifiedToday: false, currentStreak: 14),
        ],
        bestStreak: 14,
        verifiedCount: 1,
        totalCount: 3
    )
}
```

- [ ] **Step 2: Create Provider.swift**

Create `ChainWidget/Provider.swift` with the following complete contents:

```swift
import WidgetKit
import SwiftData
import Foundation

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = buildEntry()
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func buildEntry() -> WidgetEntry {
        guard let container = try? ModelContainerFactory.make(inAppGroup: true) else {
            return .placeholder
        }
        let ctx = ModelContext(container)
        let habits = (try? ctx.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let today = Date()
        var bestStreak = 0
        let summaries: [HabitSummary] = habits.map { habit in
            let streakEntries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            let isVerified = !HabitScheduler.isDue(frequency: habit.frequency, entries: streakEntries, on: today)
            let streak = StreakCalculator.current(entries: streakEntries, frequency: habit.frequency, today: today)
            if streak > bestStreak { bestStreak = streak }
            return HabitSummary(
                id: habit.id.uuidString,
                name: habit.name,
                emoji: habit.emoji,
                isVerifiedToday: isVerified,
                currentStreak: streak
            )
        }
        return WidgetEntry(
            date: today,
            habits: summaries,
            bestStreak: bestStreak,
            verifiedCount: summaries.filter(\.isVerifiedToday).count,
            totalCount: summaries.count
        )
    }
}
```

- [ ] **Step 3: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 4: Commit**

```bash
git add ChainWidget/WidgetEntry.swift ChainWidget/Provider.swift
git commit -m "feat: add WidgetEntry snapshot type and TimelineProvider"
```

---

## Task 3: VerifyHabitIntent

**Files:**
- Create: `ChainWidget/VerifyHabitIntent.swift`

- [ ] **Step 1: Create VerifyHabitIntent.swift**

Create `ChainWidget/VerifyHabitIntent.swift` with the following complete contents:

```swift
import AppIntents
import SwiftData
import WidgetKit
import Foundation

struct VerifyHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Verify Habit"

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    func perform() async throws -> some IntentResult {
        guard let container = try? ModelContainerFactory.make(inAppGroup: true) else {
            return .result()
        }
        let ctx = ModelContext(container)
        let habits = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
        guard let habit = habits.first(where: { $0.id.uuidString == habitID }) else {
            return .result()
        }
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        let alreadyVerified = habit.entries.contains {
            $0.periodStart == period && $0.status == .verified
        }
        guard !alreadyVerified else { return .result() }
        let entry = HabitEntry(habit: habit, periodStart: period)
        entry.status = .verified
        entry.verifMethod = .manual
        entry.verifiedAt = Date()
        ctx.insert(entry)
        try? ctx.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

- [ ] **Step 2: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add ChainWidget/VerifyHabitIntent.swift
git commit -m "feat: add VerifyHabitIntent AppIntent for widget verify button"
```

---

## Task 4: SmallWidgetView

**Files:**
- Create: `ChainWidget/SmallWidgetView.swift`

- [ ] **Step 1: Create SmallWidgetView.swift**

Create `ChainWidget/SmallWidgetView.swift` with the following complete contents:

```swift
import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.verifiedCount) / Double(entry.totalCount)
    }

    private var allDone: Bool {
        entry.totalCount > 0 && entry.verifiedCount == entry.totalCount
    }

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        allDone ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                Text("\(entry.verifiedCount)/\(entry.totalCount)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(width: 64, height: 64)

            Text(allDone ? "All done ✓" : "Today")
                .font(.caption2.bold())
                .foregroundStyle(allDone ? .green : .primary)

            Text("🔥 \(entry.bestStreak)d streak")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .containerBackground(.background, for: .widget)
    }
}

struct ChainSmallWidget: Widget {
    let kind = "chain.small"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SmallWidgetView(entry: entry)
                .widgetURL(URL(string: "chain://today"))
        }
        .configurationDisplayName("Chain Today")
        .description("See your daily habit progress.")
        .supportedFamilies([.systemSmall])
    }
}
```

- [ ] **Step 2: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add ChainWidget/SmallWidgetView.swift
git commit -m "feat: add SmallWidgetView with progress ring"
```

---

## Task 5: MediumWidgetView

**Files:**
- Create: `ChainWidget/MediumWidgetView.swift`

- [ ] **Step 1: Create MediumWidgetView.swift**

Create `ChainWidget/MediumWidgetView.swift` with the following complete contents:

```swift
import SwiftUI
import WidgetKit
import AppIntents

struct MediumWidgetView: View {
    let entry: WidgetEntry

    private var displayed: [HabitSummary] { Array(entry.habits.prefix(4)) }
    private var extraCount: Int { max(0, entry.habits.count - 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⛓️ Today")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(entry.verifiedCount) / \(entry.totalCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.accentColor)
            }
            ForEach(displayed) { habit in
                MediumHabitRow(habit: habit)
            }
            if extraCount > 0 {
                Text("+\(extraCount) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "chain://today"))
    }
}

private struct MediumHabitRow: View {
    let habit: HabitSummary

    var body: some View {
        HStack(spacing: 8) {
            Text(habit.emoji)
                .font(.caption)
            Text(habit.name)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            if habit.isVerifiedToday {
                Text("✅")
                    .font(.caption)
            } else {
                Button(intent: VerifyHabitIntent(habitID: habit.id)) {
                    Text("Mark done")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ChainMediumWidget: Widget {
    let kind = "chain.medium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Chain Habits")
        .description("Check off habits without opening the app.")
        .supportedFamilies([.systemMedium])
    }
}
```

- [ ] **Step 2: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add ChainWidget/MediumWidgetView.swift
git commit -m "feat: add MediumWidgetView with interactive verify buttons"
```

---

## Task 6: LockScreenWidgetView

**Files:**
- Create: `ChainWidget/LockScreenWidgetView.swift`

- [ ] **Step 1: Create LockScreenWidgetView.swift**

Create `ChainWidget/LockScreenWidgetView.swift` with the following complete contents:

```swift
import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(entry.bestStreak)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        case .accessoryInline:
            Text("⛓️ \(entry.verifiedCount) / \(entry.totalCount) done")
        default:
            Text("⛓️")
        }
    }
}

struct ChainLockScreenWidget: Widget {
    let kind = "chain.lockscreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
                .widgetURL(URL(string: "chain://today"))
        }
        .configurationDisplayName("Chain")
        .description("Streak count and today's progress on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}
```

- [ ] **Step 2: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add ChainWidget/LockScreenWidgetView.swift
git commit -m "feat: add LockScreenWidgetView for accessoryCircular and accessoryInline"
```

---

## Task 7: ChainWidgetBundle — wire all widgets

**Files:**
- Create: `ChainWidget/ChainWidgetBundle.swift`

- [ ] **Step 1: Create ChainWidgetBundle.swift**

Create `ChainWidget/ChainWidgetBundle.swift` with the following complete contents:

```swift
import WidgetKit
import SwiftUI

@main
struct ChainWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChainSmallWidget()
        ChainMediumWidget()
        ChainLockScreenWidget()
    }
}
```

- [ ] **Step 2: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add ChainWidget/ChainWidgetBundle.swift
git commit -m "feat: add ChainWidgetBundle wiring small, medium, and lock screen widgets"
```

---

## Task 8: TodayView — WidgetCenter reload

**Files:**
- Modify: `Chain/Views/Today/TodayView.swift`

- [ ] **Step 1: Add WidgetKit import and reload calls**

Replace the entire contents of `Chain/Views/Today/TodayView.swift` with:

```swift
import SwiftUI
import SwiftData
import WidgetKit

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
                            Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
                            WidgetCenter.shared.reloadAllTimelines()
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
            WidgetCenter.shared.reloadAllTimelines()
        }
        .refreshable {
            await verifyAll()
            await SmartNotificationScheduler.rescheduleForToday(habits: habits)
            WidgetCenter.shared.reloadAllTimelines()
        }
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

- [ ] **Step 2: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 68 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Today/TodayView.swift
git commit -m "feat: reload widget timelines after habit verify in TodayView"
```
