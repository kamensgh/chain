import SwiftUI

struct TodayWatchView: View {
    @Environment(WatchHabitStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.habits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.title2)
                    Text("Open Chain on iPhone to sync")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .navigationTitle("Today")
            } else {
                List {
                    ForEach(store.habits) { habit in
                        HabitRowWatchView(habit: habit) {
                            WatchSession.shared.sendVerify(habitID: habit.id)
                        }
                    }
                    if let syncedAt = store.syncedAt {
                        Text(syncedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle("Today")
            }
        }
    }
}
