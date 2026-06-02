import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: WidgetEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.verifiedCount) / Double(entry.totalCount)
    }

    private var allDone: Bool {
        entry.totalCount > 0 && entry.verifiedCount == entry.totalCount
    }

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        allDone ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                Text("\(entry.verifiedCount)/\(entry.totalCount)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(width: 64, height: 64)

            Text(allDone ? "All done ✓" : "Today")
                .font(.caption2.bold())
                .foregroundStyle(allDone ? .green : .primary)

            Text("🔥 \(entry.bestStreak)d streak")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .containerBackground(.background, for: .widget)
    }
}

struct ChainSmallWidget: Widget {
    let kind = "chain.small"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SmallWidgetView(entry: entry)
                .widgetURL(URL(string: "chain://today"))
        }
        .configurationDisplayName("Chain Today")
        .description("See your daily habit progress.")
        .supportedFamilies([.systemSmall])
    }
}
