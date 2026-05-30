import SwiftUI
import SwiftData

struct HabitRowView: View {
    let habit: Habit
    let onVerify: () -> Void

    @State private var showingScreenshotPicker = false

    private var currentPeriodStart: Date {
        HabitScheduler.periodStart(for: habit.frequency, on: Date())
    }

    private var currentEntry: HabitEntry? {
        habit.entries.first { $0.periodStart == currentPeriodStart }
    }

    private var isVerified: Bool {
        currentEntry?.status == .verified
    }

    private var currentStreak: Int {
        let streakEntries = habit.entries.map {
            StreakEntry(periodStart: $0.periodStart, status: $0.status)
        }
        return StreakCalculator.current(
            entries: streakEntries,
            frequency: habit.frequency,
            today: Date(),
            gracePeriod: habit.gracePeriodEnabled
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji circle
            ZStack {
                Circle()
                    .fill(isVerified ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 46, height: 46)
                Text(habit.emoji)
                    .font(.title3)
            }

            // Name + status + source label
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(isVerified ? .green : .secondary)
                if let entry = currentEntry, isVerified, entry.verifMethod == .auto,
                   let label = entry.sourceLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Streak badge
            if currentStreak > 0 {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            // Check button / done indicator
            if isVerified {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            } else if habit.connectorType == .screenshot {
                Button {
                    showingScreenshotPicker = true
                } label: {
                    Image(systemName: "camera.circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onVerify) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showingScreenshotPicker) {
            ScreenshotPickerView(habit: habit)
        }
    }

    private var statusLabel: String {
        guard let entry = currentEntry else {
            return "Tap to mark done"
        }
        switch entry.status {
        case .verified:
            if let value = entry.value {
                return "\(Int(value)) \(habit.goalConfig.unit.rawValue)"
            }
            return "Done ✓"
        case .pending:  return "Pending"
        case .skipped:  return "Skipped"
        }
    }
}
