import SwiftUI
import WidgetKit
import AppIntents

struct MediumWidgetView: View {
    let entry: WidgetEntry

    private var displayed: [HabitSummary] { Array(entry.habits.prefix(4)) }
    private var extraCount: Int { max(0, entry.habits.count - 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⛓️ Today")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(entry.verifiedCount) / \(entry.totalCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.accentColor)
            }
            ForEach(displayed) { habit in
                MediumHabitRow(habit: habit)
            }
            if extraCount > 0 {
                Text("+\(extraCount) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "chain://today"))
    }
}

private struct MediumHabitRow: View {
    let habit: HabitSummary

    var body: some View {
        HStack(spacing: 8) {
            Text(habit.emoji)
                .font(.caption)
            Text(habit.name)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            if habit.isVerifiedToday {
                Text("✅")
                    .font(.caption)
            } else {
                Button(intent: VerifyHabitIntent(habitID: habit.id)) {
                    Text("Mark done")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ChainMediumWidget: Widget {
    let kind = "chain.medium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Chain Habits")
        .description("Check off habits without opening the app.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
