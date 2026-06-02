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
        PhoneWatchSession.shared.activate(container: container)
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
