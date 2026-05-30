import SwiftUI
import SwiftData

@main
struct ChainApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema([]), configurations: [])
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
