import SwiftUI

struct HabitRowWatchView: View {
    let habit: WatchHabitSummary
    let onVerify: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(habit.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if habit.currentStreak > 0 {
                    Text("🔥 \(habit.currentStreak)d")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if habit.isVerifiedToday {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action: onVerify) {
                    Image(systemName: "circle")
                        .foregroundStyle(.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
