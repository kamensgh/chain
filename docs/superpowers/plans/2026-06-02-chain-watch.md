# Chain Apple Watch App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native watchOS 11 companion app with a Today habit list, verify-on-wrist support via WatchConnectivity, and a circular complication, while bumping the iOS deployment target to 18.

**Architecture:** A new `ChainWatch` watchOS app target and `ChainWatchWidget` WidgetKit extension are added to `project.yml`. WatchConnectivity syncs a `WatchPayload` snapshot from iPhone → Watch (`updateApplicationContext`), and verify taps from Watch → iPhone (`sendMessage`/`transferUserInfo` fallback). The complication reads `verifiedCount`/`totalCount` from `UserDefaults.standard`.

**Tech Stack:** SwiftUI, WatchConnectivity, WidgetKit (watchOS), SwiftData, xcodegen (`project.yml`), iOS 18 / watchOS 11.

---

## Context

Chain habit streak app — SwiftUI multiplatform macOS 14 + iOS 18, SwiftData, xcodegen. SPM `ChainDomain` target for pure domain tests.

Run tests with:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Baseline: **68 tests pass**. After Task 2: **70 tests pass**.

New directories: `ChainWatch/` and `ChainWatchWidget/` at repo root alongside `Chain/` and `ChainWidget/`.

All Watch source files (`ChainWatch/`, `ChainWatchWidget/`) are **not** in SPM sources and will not be compiled by `swift test` — only `WatchPayload.swift` (in `Chain/Models/`) gets SPM coverage.

`#if os(iOS)` guards wrap all WatchConnectivity calls in `Chain/` so the macOS build is unaffected.

---

## File map

| File | Action |
|---|---|
| `project.yml` | Modify — bump iOS 18, add watchOS 11, ChainWatch + ChainWatchWidget targets |
| `Package.swift` | Modify — bump iOS platform to `.v18` |
| `Chain/Models/WatchPayload.swift` | Create — `WatchHabitSummary` + `WatchPayload` (Codable, SPM-testable) |
| `ChainTests/WatchPayloadTests.swift` | Create — encode/decode round-trip tests |
| `Chain/WatchSession.swift` | Create — `PhoneWatchSession` singleton (iPhone-side WCSessionDelegate) |
| `Chain/ChainApp.swift` | Modify — activate WatchConnectivity on launch (iOS only) |
| `Chain/Views/Today/TodayView.swift` | Modify — send Watch snapshot after every verify (iOS only) |
| `ChainWatch/ChainWatchApp.swift` | Create — `@main` Watch app |
| `ChainWatch/WatchHabitStore.swift` | Create — `@Observable` store, drives Watch UI |
| `ChainWatch/WatchSession.swift` | Create — Watch-side WCSessionDelegate |
| `ChainWatch/Views/TodayWatchView.swift` | Create — Today habit list |
| `ChainWatch/Views/HabitRowWatchView.swift` | Create — individual habit row |
| `ChainWatchWidget/WatchWidgetProvider.swift` | Create — WidgetKit `TimelineProvider` + `WatchEntry` |
| `ChainWatchWidget/WatchComplicationView.swift` | Create — `.accessoryCircular` ring |
| `ChainWatchWidget/ChainWatchWidgetBundle.swift` | Create — `@main` WidgetBundle |

---

## Task 1: project.yml + Package.swift infrastructure

**Files:**
- Modify: `project.yml`
- Modify: `Package.swift`

- [ ] **Step 1: Replace project.yml**

Replace the entire contents of `project.yml` with:

```yaml
name: Chain
options:
  bundleIdPrefix: com.chain
  deploymentTarget:
    iOS: "18.0"
    macOS: "14.0"
    watchOS: "11.0"
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
        platforms: [iOS]
      - target: ChainWatch
        embed: true
        platforms: [watchOS]
      - sdk: WatchConnectivity.framework
        platforms: [iOS]
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
        PRODUCT_BUNDLE_IDENTIFIER: com.chain.Chain.widget
    info:
      path: ChainWidget/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension

  ChainWatch:
    type: application
    platform: watchOS
    sources:
      - path: ChainWatch
      - path: Chain/Models
      - path: Chain/Domain
    dependencies:
      - target: ChainWatchWidget
        embed: true
      - sdk: WatchConnectivity.framework
    info:
      path: ChainWatch/Info.plist
      properties:
        CFBundleDisplayName: Chain
        WKApplication: YES
        WKCompanionAppBundleIdentifier: com.chain.Chain
    settings:
      base:
        SWIFT_VERSION: "5.9"
        PRODUCT_BUNDLE_IDENTIFIER: com.chain.Chain.watch

  ChainWatchWidget:
    type: app-extension
    platform: watchOS
    sources:
      - path: ChainWatchWidget
      - path: Chain/Models
      - path: Chain/Domain
    info:
      path: ChainWatchWidget/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        SWIFT_VERSION: "5.9"
        PRODUCT_BUNDLE_IDENTIFIER: com.chain.Chain.watch.widget

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

- [ ] **Step 2: Update Package.swift**

Replace the contents of `Package.swift` with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChainDomain",
    platforms: [
        .macOS(.v14),
        .iOS(.v18)
    ],
    targets: [
        .target(
            name: "ChainDomain",
            path: "Chain",
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
            sources: ["Domain", "Connectors", "Models"]
        ),
        .testTarget(
            name: "ChainDomainTests",
            dependencies: ["ChainDomain"],
            path: "ChainTests"
        )
    ]
)
```

Note: `Chain/WatchSession.swift` lives directly in `Chain/` (not inside `Domain/`, `Connectors/`, or `Models/`), so SPM never compiles it — no exclusion entry needed.

- [ ] **Step 3: Run xcodegen**

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: `Chain.xcodeproj` regenerated with no errors. Project now contains `ChainWatch` and `ChainWatchWidget` targets.

- [ ] **Step 4: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **68 tests pass**.

- [ ] **Step 5: Commit**

```bash
git add project.yml Package.swift Chain.xcodeproj
git commit -m "feat: add ChainWatch + ChainWatchWidget targets, bump iOS to 18"
```

---

## Task 2: WatchPayload model + SPM tests

**Files:**
- Create: `Chain/Models/WatchPayload.swift`
- Create: `ChainTests/WatchPayloadTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `ChainTests/WatchPayloadTests.swift`:

```swift
import Testing
import Foundation
@testable import ChainDomain

struct WatchPayloadTests {

    @Test func roundTripWithHabits() throws {
        let summary = WatchHabitSummary(
            id: "abc", name: "Run", emoji: "🏃",
            isVerifiedToday: true, currentStreak: 7
        )
        let payload = WatchPayload(
            habits: [summary],
            syncedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(WatchPayload.self, from: data)
        #expect(decoded.habits.count == 1)
        #expect(decoded.habits[0].id == "abc")
        #expect(decoded.habits[0].name == "Run")
        #expect(decoded.habits[0].isVerifiedToday == true)
        #expect(decoded.habits[0].currentStreak == 7)
        #expect(decoded.verifiedCount == 1)
        #expect(decoded.totalCount == 1)
    }

    @Test func emptyPayloadRoundTrip() throws {
        let payload = WatchPayload(habits: [], syncedAt: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(WatchPayload.self, from: data)
        #expect(decoded.habits.isEmpty)
        #expect(decoded.verifiedCount == 0)
        #expect(decoded.totalCount == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: FAIL — `WatchHabitSummary` and `WatchPayload` not found.

- [ ] **Step 3: Create WatchPayload.swift**

Create `Chain/Models/WatchPayload.swift`:

```swift
import Foundation

struct WatchHabitSummary: Codable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isVerifiedToday: Bool
    let currentStreak: Int
}

struct WatchPayload: Codable {
    let habits: [WatchHabitSummary]
    let syncedAt: Date

    var verifiedCount: Int { habits.filter(\.isVerifiedToday).count }
    var totalCount: Int { habits.count }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **70 tests pass** (68 existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add Chain/Models/WatchPayload.swift ChainTests/WatchPayloadTests.swift
git commit -m "feat: add WatchPayload Codable model with SPM tests"
```

---

## Task 3: iPhone WatchSession

**Files:**
- Create: `Chain/WatchSession.swift`
- Modify: `Chain/ChainApp.swift`

- [ ] **Step 1: Create Chain/WatchSession.swift**

Create `Chain/WatchSession.swift`:

```swift
#if os(iOS)
import WatchConnectivity
import SwiftData
import WidgetKit
import Foundation

@Observable
final class PhoneWatchSession: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSession()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSnapshot(habits: [Habit]) {
        guard WCSession.default.activationState == .activated else { return }
        let today = Date()
        let summaries: [WatchHabitSummary] = habits.map { habit in
            let entries = habit.entries.map {
                StreakEntry(periodStart: $0.periodStart, status: $0.status)
            }
            let isVerified = !HabitScheduler.isDue(
                frequency: habit.frequency, entries: entries, on: today)
            let streak = StreakCalculator.current(
                entries: entries, frequency: habit.frequency, today: today)
            return WatchHabitSummary(
                id: habit.id.uuidString,
                name: habit.name,
                emoji: habit.emoji,
                isVerifiedToday: isVerified,
                currentStreak: streak
            )
        }
        let payload = WatchPayload(habits: summaries, syncedAt: today)
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        try? WCSession.default.updateApplicationContext(dict)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleVerify(message)
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleVerify(userInfo)
    }

    // MARK: - Private

    private func handleVerify(_ dict: [String: Any]) {
        guard dict["action"] as? String == "verify",
              let habitID = dict["habitID"] as? String else { return }
        Task { @MainActor in
            guard let container = try? ModelContainerFactory.make(inAppGroup: true) else { return }
            let ctx = ModelContext(container)
            let habits = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
            guard let habit = habits.first(where: { $0.id.uuidString == habitID }) else { return }
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            let alreadyDone = habit.entries.contains {
                $0.periodStart == period && $0.status == .verified
            }
            guard !alreadyDone else { return }
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = .verified
            entry.verifMethod = .manual
            entry.verifiedAt = Date()
            ctx.insert(entry)
            try? ctx.save()
            WidgetCenter.shared.reloadAllTimelines()
            let updated = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
            sendSnapshot(habits: updated)
        }
    }
}
#endif
```

- [ ] **Step 2: Update Chain/ChainApp.swift**

Replace the entire contents of `Chain/ChainApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

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
            container = try ModelContainerFactory.make(inAppGroup: true)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        #if os(iOS)
        PhoneWatchSession.shared.activate()
        #endif
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

- [ ] **Step 3: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **70 tests pass**.

- [ ] **Step 4: Commit**

```bash
git add Chain/WatchSession.swift Chain/ChainApp.swift
git commit -m "feat: add PhoneWatchSession — sends habit snapshots, handles Watch verify"
```

---

## Task 4: TodayView snapshot sends

**Files:**
- Modify: `Chain/Views/Today/TodayView.swift`

- [ ] **Step 1: Update TodayView.swift**

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

                if let companion = companions.first {
                    CompanionCardView(companion: companion, habits: habits)
                }

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
                            #if os(iOS)
                            PhoneWatchSession.shared.sendSnapshot(habits: habits)
                            #endif
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
            #if os(iOS)
            PhoneWatchSession.shared.sendSnapshot(habits: habits)
            #endif
        }
        .refreshable {
            await verifyAll()
            await SmartNotificationScheduler.rescheduleForToday(habits: habits)
            WidgetCenter.shared.reloadAllTimelines()
            #if os(iOS)
            PhoneWatchSession.shared.sendSnapshot(habits: habits)
            #endif
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

Expected: **70 tests pass**.

- [ ] **Step 3: Commit**

```bash
git add Chain/Views/Today/TodayView.swift
git commit -m "feat: send Watch snapshot after every habit verify in TodayView"
```

---

## Task 5: WatchHabitStore + Watch-side WatchSession

**Files:**
- Create: `ChainWatch/WatchHabitStore.swift`
- Create: `ChainWatch/WatchSession.swift`

- [ ] **Step 1: Create ChainWatch directory**

```bash
mkdir -p /Users/mac/Documents/projects/chain/ChainWatch/Views
```

- [ ] **Step 2: Create ChainWatch/WatchHabitStore.swift**

Create `ChainWatch/WatchHabitStore.swift`:

```swift
import Foundation
import Observation
import WidgetKit

@Observable
final class WatchHabitStore {
    static let shared = WatchHabitStore()
    private init() {}

    var habits: [WatchHabitSummary] = []
    var syncedAt: Date?

    var verifiedCount: Int { habits.filter(\.isVerifiedToday).count }
    var totalCount: Int { habits.count }

    func update(from payload: WatchPayload) {
        habits = payload.habits
        syncedAt = payload.syncedAt
        UserDefaults.standard.set(payload.verifiedCount, forKey: "watch_verifiedCount")
        UserDefaults.standard.set(payload.totalCount, forKey: "watch_totalCount")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func markVerified(habitID: String) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let h = habits[idx]
        habits[idx] = WatchHabitSummary(
            id: h.id, name: h.name, emoji: h.emoji,
            isVerifiedToday: true, currentStreak: h.currentStreak
        )
        UserDefaults.standard.set(verifiedCount, forKey: "watch_verifiedCount")
        UserDefaults.standard.set(totalCount, forKey: "watch_totalCount")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

- [ ] **Step 3: Create ChainWatch/WatchSession.swift**

Create `ChainWatch/WatchSession.swift`:

```swift
import WatchConnectivity
import Foundation

final class WatchSession: NSObject, WCSessionDelegate {
    static let shared = WatchSession()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendVerify(habitID: String) {
        WatchHabitStore.shared.markVerified(habitID: habitID)
        let message = ["action": "verify", "habitID": habitID]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: applicationContext),
              let payload = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        DispatchQueue.main.async {
            WatchHabitStore.shared.update(from: payload)
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **70 tests pass**.

- [ ] **Step 5: Commit**

```bash
git add ChainWatch/WatchHabitStore.swift ChainWatch/WatchSession.swift
git commit -m "feat: add WatchHabitStore and Watch-side WatchSession"
```

---

## Task 6: Watch app UI

**Files:**
- Create: `ChainWatch/ChainWatchApp.swift`
- Create: `ChainWatch/Views/HabitRowWatchView.swift`
- Create: `ChainWatch/Views/TodayWatchView.swift`

- [ ] **Step 1: Create ChainWatch/ChainWatchApp.swift**

Create `ChainWatch/ChainWatchApp.swift`:

```swift
import SwiftUI

@main
struct ChainWatchApp: App {
    init() {
        WatchSession.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            TodayWatchView()
                .environment(WatchHabitStore.shared)
        }
    }
}
```

- [ ] **Step 2: Create ChainWatch/Views/HabitRowWatchView.swift**

Create `ChainWatch/Views/HabitRowWatchView.swift`:

```swift
import SwiftUI

struct HabitRowWatchView: View {
    let habit: WatchHabitSummary
    let onVerify: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(habit.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if habit.currentStreak > 0 {
                    Text("🔥 \(habit.currentStreak)d")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if habit.isVerifiedToday {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action: onVerify) {
                    Image(systemName: "circle")
                        .foregroundStyle(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 3: Create ChainWatch/Views/TodayWatchView.swift**

Create `ChainWatch/Views/TodayWatchView.swift`:

```swift
import SwiftUI

struct TodayWatchView: View {
    @Environment(WatchHabitStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.habits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.title2)
                    Text("Open Chain on iPhone to sync")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            } else {
                List {
                    ForEach(store.habits) { habit in
                        HabitRowWatchView(habit: habit) {
                            WatchSession.shared.sendVerify(habitID: habit.id)
                        }
                    }
                    if let syncedAt = store.syncedAt {
                        Text(syncedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle("Today")
            }
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **70 tests pass**.

- [ ] **Step 5: Commit**

```bash
git add ChainWatch/ChainWatchApp.swift ChainWatch/Views/TodayWatchView.swift ChainWatch/Views/HabitRowWatchView.swift
git commit -m "feat: add Watch app UI — Today list with verify, empty state, last synced"
```

---

## Task 7: Watch complication

**Files:**
- Create: `ChainWatchWidget/WatchWidgetProvider.swift`
- Create: `ChainWatchWidget/WatchComplicationView.swift`
- Create: `ChainWatchWidget/ChainWatchWidgetBundle.swift`

- [ ] **Step 1: Create ChainWatchWidget directory**

```bash
mkdir -p /Users/mac/Documents/projects/chain/ChainWatchWidget
```

- [ ] **Step 2: Create ChainWatchWidget/WatchWidgetProvider.swift**

Create `ChainWatchWidget/WatchWidgetProvider.swift`:

```swift
import WidgetKit
import Foundation

struct WatchEntry: TimelineEntry {
    let date: Date
    let verifiedCount: Int
    let totalCount: Int
}

struct WatchWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, verifiedCount: 1, totalCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = buildEntry()
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func buildEntry() -> WatchEntry {
        let verified = UserDefaults.standard.integer(forKey: "watch_verifiedCount")
        let total = UserDefaults.standard.integer(forKey: "watch_totalCount")
        return WatchEntry(date: .now, verifiedCount: verified, totalCount: total)
    }
}
```

- [ ] **Step 3: Create ChainWatchWidget/WatchComplicationView.swift**

Create `ChainWatchWidget/WatchComplicationView.swift`:

```swift
import SwiftUI
import WidgetKit

struct WatchComplicationView: View {
    let entry: WatchEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.verifiedCount) / Double(entry.totalCount)
    }

    private var allDone: Bool {
        entry.totalCount > 0 && entry.verifiedCount == entry.totalCount
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        allDone ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                if allDone {
                    Text("✓")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                } else {
                    Text("\(entry.verifiedCount)/\(entry.totalCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
        }
        .widgetURL(URL(string: "chain://today"))
    }
}

struct ChainWatchWidget: Widget {
    let kind = "chain.watch.circular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWidgetProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Chain")
        .description("Today's habit progress.")
        .supportedFamilies([.accessoryCircular])
    }
}
```

- [ ] **Step 4: Create ChainWatchWidget/ChainWatchWidgetBundle.swift**

Create `ChainWatchWidget/ChainWatchWidgetBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct ChainWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChainWatchWidget()
    }
}
```

- [ ] **Step 5: Run xcodegen (new directory picked up)**

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: No errors. `ChainWatchWidget` sources picked up.

- [ ] **Step 6: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: **70 tests pass**.

- [ ] **Step 7: Commit**

```bash
git add ChainWatchWidget/ Chain.xcodeproj
git commit -m "feat: add ChainWatchWidget — accessoryCircular progress ring complication"
```
