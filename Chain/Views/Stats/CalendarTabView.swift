import SwiftUI
import SwiftData

struct CalendarTabView: View {
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
                VStack(spacing: 24) {
                    ForEach(habits) { habit in
                        HabitCalendarView(habit: habit)
                    }
                }
                .padding()
            }
        }
    }
}

private struct HabitCalendarView: View {
    let habit: Habit
    private let cal = Calendar.current

    // 30 days oldest-first: index 0 is 29 days ago, index 29 is today
    private var days: [Date] {
        let today = cal.startOfDay(for: Date())
        return (0..<30).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func cellColor(for day: Date) -> Color {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: day)
        let isVerified = habit.entries.contains {
            $0.periodStart == period && $0.status == .verified
        }
        return isVerified ? Color.accentColor : Color.secondary.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(habit.emoji).font(.system(size: 16))
                Text(habit.name).font(.subheadline.bold())
            }

            let columns = Array(repeating: GridItem(.fixed(28), spacing: 4), count: 6)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cellColor(for: day))
                        .frame(width: 28, height: 28)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
