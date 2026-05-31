import SwiftUI
import SwiftData

struct MenuBarHabitRowView: View {
    let habit: Habit
    let allHabits: [Habit]
    let companions: [Companion]

    @Environment(\.modelContext) private var context

    private var isVerified: Bool {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(habit.emoji)
                .font(.body)
            Text(habit.name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            if isVerified {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Button {
                    HabitVerifier.verify(habit, allHabits: allHabits, context: context, companions: companions)
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
