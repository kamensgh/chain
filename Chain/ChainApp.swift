import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

    init() {
        do {
            // Task 3: replace Schema([]) with ModelContainer(for: Habit.self, HabitEntry.self)
            container = try ModelContainer(for: Schema([]))
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
