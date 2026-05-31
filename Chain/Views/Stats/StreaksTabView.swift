import SwiftUI
import SwiftData

struct StreaksTabView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    var body: some View {
        if habits.isEmpty {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "target",
                description: Text("Go to Habits to add your first one.")
            )
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(habits) { habit in
                        StreakRowView(habit: habit)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct StreakRowView: View {
    let habit: Habit

    private var streakEntries: [StreakEntry] {
        habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
    }

    private var currentStreak: Int {
        StreakCalculator.current(
            entries: streakEntries,
            frequency: habit.frequency,
            today: Date(),
            gracePeriod: habit.gracePeriodEnabled
        )
    }

    private var longestStreak: Int {
        StreakCalculator.longest(entries: streakEntries, frequency: habit.frequency)
    }

    private var rate: Double {
        StatsCalculator.completionRate(entries: streakEntries, frequency: habit.frequency, days: 30, today: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(habit.emoji)
                    .font(.system(size: 16))
            }

            Text(habit.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            Spacer()

            HStack(spacing: 12) {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Label("\(longestStreak)", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                Text("\(Int(rate * 100))%")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
