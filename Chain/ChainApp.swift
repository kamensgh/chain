// Chain/ChainApp.swift
import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Habit.self, HabitEntry.self, Companion.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .task { await ensureCompanionExists() }
        }
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
