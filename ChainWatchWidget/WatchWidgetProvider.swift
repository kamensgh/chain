import WidgetKit
import Foundation

struct WatchEntry: TimelineEntry {
    let date: Date
    let verifiedCount: Int
    let totalCount: Int
}

struct WatchWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, verifiedCount: 1, totalCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = buildEntry()
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func buildEntry() -> WatchEntry {
        let verified = UserDefaults.standard.integer(forKey: "watch_verifiedCount")
        let total = UserDefaults.standard.integer(forKey: "watch_totalCount")
        return WatchEntry(date: .now, verifiedCount: verified, totalCount: total)
    }
}
