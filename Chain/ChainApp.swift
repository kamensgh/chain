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
            Text("Chain")
                .modelContainer(container)
        }
    }
}
