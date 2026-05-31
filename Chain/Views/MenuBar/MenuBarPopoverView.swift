import SwiftUI
import SwiftData

struct MenuBarPopoverView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Date + companion header
            VStack(spacing: 8) {
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let companion = companions.first {
                    CompanionMenuBarView(companion: companion, habits: habits)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)

            Divider()

            // Habit list
            if habits.isEmpty {
                Text("No habits yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(habits) { habit in
                            MenuBarHabitRowView(habit: habit, allHabits: habits, companions: companions)
                            if habit.id != habits.last?.id {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            Button("Open Chain") {
                openWindow(id: "main")
                #if os(macOS)
                NSApp.activate(ignoringOtherApps: true)
                #endif
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }
}
