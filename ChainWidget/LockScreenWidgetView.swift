import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(entry.bestStreak)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        case .accessoryInline:
            Text("⛓️ \(entry.verifiedCount) / \(entry.totalCount) done")
        default:
            Text("⛓️")
        }
    }
}

struct ChainLockScreenWidget: Widget {
    let kind = "chain.lockscreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
                .widgetURL(URL(string: "chain://today"))
        }
        .configurationDisplayName("Chain")
        .description("Streak count and today's progress on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}
