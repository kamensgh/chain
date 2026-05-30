import SwiftUI
import SwiftData

struct HabitsListView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(habits) { habit in
                NavigationLink(destination: AddHabitView(habit: habit)) {
                    HStack(spacing: 10) {
                        Text(habit.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name).font(.subheadline.weight(.medium))
                            Text(habit.frequency.rawValue.capitalized + " · " + habit.connectorType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddHabitView() }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { habits[$0] }.forEach { context.delete($0) }
        try? context.save()
    }
}
