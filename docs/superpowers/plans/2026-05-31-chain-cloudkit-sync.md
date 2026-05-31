# Chain CloudKit Sync-Ready Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Chain app CloudKit-activatable by fixing model compatibility, introducing `ModelContainerFactory`, and stubbing iCloud entitlements — without changing runtime behavior on the local path.

**Architecture:** A `ModelContainerFactory` enum owns all `ModelContainer` creation, switching between a local and a CloudKit-backed store based on a `CLOUDKIT_SYNC` Swift build flag (off by default). All three SwiftData models are made CloudKit-compatible (defaults on stored properties, `@Attribute(.unique)` removed). Entitlements gain iCloud stubs.

**Tech Stack:** SwiftData `ModelContainer`/`ModelConfiguration`, `#if CLOUDKIT_SYNC` build flag, `UNUserNotificationCenter` unchanged, xcodegen, SPM `ChainDomain` for regression tests.

---

## Context

This is the Chain habit streak app — SwiftUI multiplatform (macOS 14 + iOS 17), SwiftData persistence, SPM `ChainDomain` target for headless domain tests.

Run tests with:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Expected baseline: **60 tests pass**.

The three SwiftData model files (`Habit.swift`, `HabitEntry.swift`, `Companion.swift`) are **excluded from SPM** (they import SwiftData) — the only automated verification available is that the 60 existing SPM tests still pass after each change. The CloudKit path itself cannot be tested without a real Apple Developer account.

`Package.swift` sources are `["Domain", "Connectors", "Models"]` — `Chain/Persistence/` is outside these directories, so `ModelContainerFactory.swift` is invisible to SPM and **no Package.swift exclusion is needed**.

---

## File map

| File | Action |
|---|---|
| `Chain/Models/Habit.swift` | Modify — remove `@Attribute(.unique)`, add property defaults |
| `Chain/Models/HabitEntry.swift` | Modify — remove `@Attribute(.unique)`, add property defaults |
| `Chain/Models/Companion.swift` | Modify — remove `@Attribute(.unique)`, add property defaults |
| `Chain/Persistence/ModelContainerFactory.swift` | Create — owns container creation, switches on `CLOUDKIT_SYNC` |
| `Chain/ChainApp.swift` | Modify — replace inline container init with `ModelContainerFactory.make()` |
| `Chain/Chain.entitlements` | Modify — add iCloud capability keys |

---

## Task 1: Model compatibility

**Files:**
- Modify: `Chain/Models/Habit.swift`
- Modify: `Chain/Models/HabitEntry.swift`
- Modify: `Chain/Models/Companion.swift`

CloudKit requires every stored property to be optional or have a default value at the property declaration. `@Attribute(.unique)` is incompatible with CloudKit and must be removed from all three models. The init methods are unchanged — they still set all properties explicitly.

- [ ] **Step 1: Update Habit.swift**

Replace the entire contents of `Chain/Models/Habit.swift` with:

```swift
import SwiftData
import Foundation

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colorHex: String = ""
    var frequencyRaw: String = Frequency.daily.rawValue
    var goalConfigData: Data = Data()
    var connectorTypeRaw: String = ConnectorType.manual.rawValue
    var connectorEndpoint: String?
    var reminderTime: Date?
    var gracePeriodEnabled: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry] = []

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var goalConfig: GoalConfig {
        get { (try? Self.decoder.decode(GoalConfig.self, from: goalConfigData)) ?? .boolean }
        set {
            goalConfigData = (try? Self.encoder.encode(newValue)) ?? {
                assertionFailure("GoalConfig encoding failed — check Codable conformance")
                return Data()
            }()
        }
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
        self.goalConfigData = (try? JSONEncoder().encode(goalConfig)) ?? {
            assertionFailure("GoalConfig encoding failed in Habit.init")
            return Data()
        }()
        self.connectorTypeRaw = ConnectorType.manual.rawValue
        self.gracePeriodEnabled = false
        self.createdAt = Date()
    }
}
```

- [ ] **Step 2: Update HabitEntry.swift**

Replace the entire contents of `Chain/Models/HabitEntry.swift` with:

```swift
import SwiftData
import Foundation

@Model
final class HabitEntry {
    var id: UUID = UUID()
    var periodStart: Date = Date.now
    var statusRaw: String = EntryStatus.pending.rawValue
    var verifMethodRaw: String = VerifMethod.manual.rawValue
    var value: Double?
    var screenshotPath: String?
    var sourceLabel: String?
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

- [ ] **Step 3: Update Companion.swift**

Replace the entire contents of `Chain/Models/Companion.swift` with:

```swift
import SwiftData
import Foundation

@Model
final class Companion {
    var id: UUID = UUID()
    var typeRaw: String = CompanionType.pet.rawValue
    var xp: Double = 0
    var accessoriesUnlocked: [String] = []
    var createdAt: Date = Date.now
    var lastXPDate: Date?

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

    @discardableResult
    func applyXP(_ delta: Double) -> PetStage? {
        let oldStage = CompanionEngine.stage(xp: xp)
        xp = max(oldStage.xpFloor, xp + delta)
        let newStage = CompanionEngine.stage(xp: xp)
        if newStage != oldStage && !accessoriesUnlocked.contains(newStage.rawValue) {
            accessoriesUnlocked.append(newStage.rawValue)
            return newStage
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass. The models are excluded from SPM so no model code is compiled — this confirms no regressions in the domain layer.

- [ ] **Step 5: Commit**

```bash
git add Chain/Models/Habit.swift Chain/Models/HabitEntry.swift Chain/Models/Companion.swift
git commit -m "feat: make SwiftData models CloudKit-compatible (remove @Attribute(.unique), add defaults)"
```

---

## Task 2: ModelContainerFactory + ChainApp

**Files:**
- Create: `Chain/Persistence/ModelContainerFactory.swift`
- Modify: `Chain/ChainApp.swift`

`Chain/Persistence/` is outside the SPM source directories (`["Domain", "Connectors", "Models"]`), so no Package.swift exclusion is needed.

- [ ] **Step 1: Create Chain/Persistence/ModelContainerFactory.swift**

First verify the directory exists (or create it):
```bash
mkdir -p /Users/mac/Documents/projects/chain/Chain/Persistence
```

Create `Chain/Persistence/ModelContainerFactory.swift`:

```swift
import SwiftData

enum ModelContainerFactory {

    static func make() throws -> ModelContainer {
        let schema = Schema([Habit.self, HabitEntry.self, Companion.self])
        #if CLOUDKIT_SYNC
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.chain.app")
        )
        #else
        let config = ModelConfiguration(schema: schema)
        #endif
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2: Update ChainApp.swift**

In `Chain/ChainApp.swift`, replace the container init line:

```swift
// Replace this line:
container = try ModelContainer(for: Habit.self, HabitEntry.self, Companion.self)

// With this line:
container = try ModelContainerFactory.make()
```

The full updated `init()` block becomes:

```swift
init() {
    do {
        container = try ModelContainerFactory.make()
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}
```

No other changes to `ChainApp.swift`.

- [ ] **Step 3: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass. `ModelContainerFactory.swift` is in `Chain/Persistence/` which is outside SPM sources — no compilation impact.

- [ ] **Step 4: Regenerate Xcode project**

`ModelContainerFactory.swift` is a new file that xcodegen needs to pick up:

```bash
cd /Users/mac/Documents/projects/chain && xcodegen generate
```

Expected: `Chain.xcodeproj` regenerated with `ModelContainerFactory.swift` included in the Chain target.

- [ ] **Step 5: Commit**

```bash
git add Chain/Persistence/ModelContainerFactory.swift Chain/ChainApp.swift Chain.xcodeproj
git commit -m "feat: add ModelContainerFactory, wire ChainApp to use it"
```

---

## Task 3: Entitlements

**Files:**
- Modify: `Chain/Chain.entitlements`

Add the iCloud service and container identifier keys. These are inert without a real `DEVELOPMENT_TEAM` — the app builds and runs locally exactly as before.

- [ ] **Step 1: Update Chain.entitlements**

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
</dict>
</plist>
```

- [ ] **Step 2: Run tests**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Expected: 60 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Chain/Chain.entitlements
git commit -m "feat: stub iCloud/CloudKit entitlements for future activation"
```
