import SwiftUI
import SwiftData

#if os(iOS)
private struct HabitPrefill: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
}
#endif

struct HabitsListView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    #if os(iOS)
    @State private var showingSuggest = false
    @State private var addPrefill: HabitPrefill? = nil
    @State private var pendingPrefill: HabitPrefill? = nil
    #endif

    var body: some View {
        List {
            ForEach(habits) { habit in
                habitRow(habit)
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSuggest = true
                } label: {
                    Label("Suggest", systemImage: "sparkles")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddHabitView() }
        }
        #if os(iOS)
        .sheet(isPresented: $showingSuggest, onDismiss: {
            if let p = pendingPrefill {
                addPrefill = p
                pendingPrefill = nil
            }
        }) {
            NavigationStack {
                SuggestHabitsView(existingNames: habits.map(\.name)) { selected in
                    pendingPrefill = HabitPrefill(name: selected.name, emoji: selected.emoji)
                }
            }
        }
        .sheet(item: $addPrefill) { prefill in
            NavigationStack {
                AddHabitView(prefillName: prefill.name, prefillEmoji: prefill.emoji)
            }
        }
        #endif
    }

    @ViewBuilder
    private func habitRow(_ habit: Habit) -> some View {
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
        .contextMenu {
            Button(role: .destructive) {
                context.delete(habit)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { habits[$0] }.forEach { context.delete($0) }
        try? context.save()
    }
}
