import SwiftUI

@main
struct ChainWatchApp: App {
    init() {
        WatchSession.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            TodayWatchView()
                .environment(WatchHabitStore.shared)
        }
    }
}
