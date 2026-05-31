# Chain CloudKit Sync — Design Spec
**Date:** 2026-05-31
**Status:** Approved

---

## Overview

Prepare the Chain app for CloudKit sync using SwiftData's native `cloudKitDatabase: .private` integration. No Apple Developer account is required yet — the work makes CloudKit activatable with a single build flag once a real team ID exists. The app builds and runs identically on the local-only path until then.

---

## Architecture

### New files

| File | Purpose |
|---|---|
| `Chain/Persistence/ModelContainerFactory.swift` | Creates `ModelContainer` — local or CloudKit based on `CLOUDKIT_SYNC` build flag |

### Modified files

| File | Change |
|---|---|
| `Chain/ChainApp.swift` | Replace inline container init with `ModelContainerFactory.make()` |
| `Chain/Models/Habit.swift` | Remove `@Attribute(.unique)`, add defaults to stored properties |
| `Chain/Models/HabitEntry.swift` | Remove `@Attribute(.unique)`, add defaults to stored properties |
| `Chain/Models/Companion.swift` | Remove `@Attribute(.unique)`, add defaults to stored properties |
| `Chain/Chain.entitlements` | Add iCloud capability keys (harmless without a real team ID) |
| `Package.swift` | Add `"Persistence/ModelContainerFactory.swift"` to exclude list |

### No changes to

- `project.yml` — `CODE_SIGN_ENTITLEMENTS` already points to `Chain/Chain.entitlements`; the `CLOUDKIT_SYNC` flag is added manually at activation time
- Domain layer, views, connectors, stats, notifications

---

## ModelContainerFactory

`Chain/Persistence/ModelContainerFactory.swift`

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

The container identifier `iCloud.com.chain.app` is a placeholder. Replace it with the real identifier created in the Apple Developer portal before enabling the flag.

---

## ChainApp changes

Replace the inline `ModelContainer` init:

```swift
// Before
container = try ModelContainer(for: Habit.self, HabitEntry.self, Companion.self)

// After
container = try ModelContainerFactory.make()
```

No other changes to `ChainApp.swift`.

---

## Model compatibility

CloudKit requires every stored property to be optional or have a default value at the property declaration. `@Attribute(.unique)` is incompatible with CloudKit (it uses its own record-level deduplication) and must be removed from all three models.

### Habit

```swift
@Model
final class Habit {
    var id: UUID = UUID()                            // removed @Attribute(.unique)
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
    // ... computed properties and init unchanged
}
```

### HabitEntry

```swift
@Model
final class HabitEntry {
    var id: UUID = UUID()                            // removed @Attribute(.unique)
    var periodStart: Date = Date.now
    var statusRaw: String = EntryStatus.pending.rawValue
    var verifMethodRaw: String = VerifMethod.manual.rawValue
    var value: Double?
    var screenshotPath: String?
    var sourceLabel: String?
    var verifiedAt: Date?
    var habit: Habit?
    // ... computed properties and init unchanged
}
```

### Companion

```swift
@Model
final class Companion {
    var id: UUID = UUID()                            // removed @Attribute(.unique)
    var typeRaw: String = CompanionType.pet.rawValue
    var xp: Double = 0
    var accessoriesUnlocked: [String] = []
    var createdAt: Date = Date.now
    var lastXPDate: Date?
    // ... computed properties, init, applyXP unchanged
}
```

Adding property-level defaults does not change runtime behavior on the local path: the `init()` methods still set all properties explicitly and take precedence.

---

## Entitlements

Add CloudKit capability keys to `Chain/Chain.entitlements`:

```xml
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.chain.app</string>
</array>
```

These keys are inert without a real `DEVELOPMENT_TEAM` in `project.yml`. The app builds and runs unsigned (local simulator/Mac) exactly as before.

---

## Package.swift

`ModelContainerFactory` imports `SwiftData`, which is unavailable in the headless SPM test build. Add it to the `ChainDomain` target's exclude list alongside the other app-only files:

```swift
"Connectors/NotificationScheduler.swift",
"Persistence/ModelContainerFactory.swift"
```

---

## Activation instructions (for future reference)

When you have an Apple Developer account:

1. Create an iCloud container (`iCloud.com.chain.app` or your chosen ID) in the Developer portal
2. Update `DEVELOPMENT_TEAM` in `project.yml` with your real team ID
3. Update the container identifier in `ModelContainerFactory.swift` if you used a different ID
4. Add `-D CLOUDKIT_SYNC` to `OTHER_SWIFT_FLAGS` in `project.yml` for the Chain target
5. Run `xcodegen generate` and build

---

## Out of Scope (v1)

- Manual conflict resolution UI
- Sharing habits across iCloud accounts
- CloudKit public database
- Migration from existing local data (SwiftData + CloudKit handles this automatically on first sync)
- Per-device sync preferences
