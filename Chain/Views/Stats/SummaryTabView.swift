import SwiftUI
import SwiftData

struct SummaryTabView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    private var onTrackCount: Int {
        habits.filter { habit in
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
        }.count
    }

    private var globalRate: Double {
        guard !habits.isEmpty else { return 0.0 }
        let rates = habits.map { habit -> Double in
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return StatsCalculator.completionRate(entries: entries, frequency: habit.frequency, days: 30, today: Date())
        }
        return rates.reduce(0, +) / Double(rates.count)
    }

    var body: some View {
        if habits.isEmpty {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "target",
                description: Text("Go to Habits to add your first one.")
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    // Headline card
                    HStack(spacing: 0) {
                        statCell(value: "\(onTrackCount) / \(habits.count)", label: "On track today")
                        Divider().frame(height: 48)
                        statCell(value: "\(Int(globalRate * 100))%", label: "30-day avg")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    // Per-habit progress bars
                    VStack(spacing: 0) {
                        ForEach(habits) { habit in
                            HabitProgressRowView(habit: habit)
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HabitProgressRowView: View {
    let habit: Habit

    private var rate: Double {
        let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
        return StatsCalculator.completionRate(entries: entries, frequency: habit.frequency, days: 30, today: Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(habit.emoji).font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.subheadline)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * rate, height: 6)
                            .animation(.spring(response: 0.4), value: rate)
                    }
                }
                .frame(height: 6)
            }

            Text("\(Int(rate * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
