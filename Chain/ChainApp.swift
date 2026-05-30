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
            // TODO: Task 7 — replace with ContentView()
            Text("Chain")
                .modelContainer(container)
        }
    }
}
