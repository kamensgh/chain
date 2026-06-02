import SwiftUI
import WidgetKit

struct WatchComplicationView: View {
    let entry: WatchEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.verifiedCount) / Double(entry.totalCount)
    }

    private var allDone: Bool {
        entry.totalCount > 0 && entry.verifiedCount == entry.totalCount
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        allDone ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                if allDone {
                    Text("✓")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                } else {
                    Text("\(entry.verifiedCount)/\(entry.totalCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
        }
        .widgetURL(URL(string: "chain://today"))
    }
}

struct ChainWatchWidget: Widget {
    let kind = "chain.watch.circular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWidgetProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Chain")
        .description("Today's habit progress.")
        .supportedFamilies([.accessoryCircular])
    }
}
