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
        // Passing inAppGroup: true moves the store to the shared App Group container.
        // Existing installs with data in the default sandbox will start empty until
        // a migration step copies the old SQLite file to the new location.
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
