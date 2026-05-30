import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]
    @Environment(\.modelContext) private var context

    private var doneCount: Int {
        habits.filter { habit in
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Greeting + progress
                VStack(alignment: .leading, spacing: 6) {
                    Text(greetingText)
                        .font(.title2.bold())
                    if !habits.isEmpty {
                        Text("\(doneCount) of \(habits.count) done today")
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(
                                        width: geo.size.width * (Double(doneCount) / Double(habits.count)),
                                        height: 8
                                    )
                                    .animation(.spring(response: 0.4), value: doneCount)
                            }
                        }
                        .frame(height: 8)
                    }
                }

                // Companion card
                if let companion = companions.first {
                    CompanionCardView(companion: companion, habits: habits)
                }

                // Habit list
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "target",
                        description: Text("Go to Habits to add your first one.")
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(habits) { habit in
                        HabitRowView(habit: habit) {
                            verify(habit: habit)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Today")
        .task { await verifyAll() }
        .refreshable { await verifyAll() }
    }

    private func verifyAll() async {
        await withTaskGroup(of: Void.self) { group in
            for habit in habits {
                guard habit.connectorType != .manual,
                      habit.connectorType != .screenshot else { continue }
                let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
                let alreadyDone = habit.entries.contains {
                    $0.periodStart == period && $0.status == .verified
                }
                guard !alreadyDone else { continue }
                group.addTask {
                    await ConnectorService.shared.verify(habit: habit, context: context)
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning! ☀️"
        case 12..<17: return "Good afternoon! 🌤️"
        default:      return "Good evening! 🌙"
        }
    }

    private func verify(habit: Habit) {
        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
            guard existing.status != .verified else { return }
            existing.status = .verified
            existing.verifMethod = .manual
            existing.verifiedAt = Date()
        } else {
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = .verified
            entry.verifMethod = .manual
            entry.verifiedAt = Date()
            context.insert(entry)
        }
        applyDailyXP()
        try? context.save()
    }

    private func applyDailyXP() {
        guard let companion = companions.first else { return }
        // Only award XP once per calendar day
        if let last = companion.lastXPDate, Calendar.current.isDateInToday(last) { return }
        let needStates: [NeedState] = CompanionNeed.allCases.prefix(min(habits.count, 3)).map { need in
            let habit = habits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
        }
        let delta = CompanionEngine.xpDelta(needStates: needStates)
        if delta > 0 {
            companion.applyXP(delta)
            companion.lastXPDate = Date()
        }
    }
}
