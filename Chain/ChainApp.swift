import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.make()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
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
