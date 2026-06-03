import SwiftUI
import SwiftData
import WidgetKit

struct TodayView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]
    @Environment(\.modelContext) private var context

    @State private var showingAddHabit = false

    private var doneCount: Int {
        habits.filter { habit in
            let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
            return habit.entries.contains { $0.periodStart == period && $0.status == .verified }
        }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                        VStack(spacing: 20) {
                            Text("🎯")
                                .font(.system(size: 56))
                            VStack(spacing: 6) {
                                Text("No habits yet")
                                    .font(.headline)
                                Text("Start building your first chain.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                showingAddHabit = true
                            } label: {
                                Label("Create your first habit", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(habits) { habit in
                            HabitRowView(habit: habit) {
                                HabitVerifier.verify(habit, allHabits: habits, context: context, companions: companions)
                                Task { await SmartNotificationScheduler.rescheduleForToday(habits: habits) }
                                WidgetCenter.shared.reloadAllTimelines()
                                #if os(iOS)
                                PhoneWatchSession.shared.sendSnapshot(habits: habits)
                                #endif
                            }
                        }
                    }
                }
                .padding()
            }

            if !habits.isEmpty {
                Button {
                    showingAddHabit = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Today")
        .task {
            await NotificationScheduler.rescheduleAll(habits)
            await verifyAll()
            await SmartNotificationScheduler.rescheduleForToday(habits: habits)
            WidgetCenter.shared.reloadAllTimelines()
            #if os(iOS)
            PhoneWatchSession.shared.sendSnapshot(habits: habits)
            #endif
        }
        .refreshable {
            await verifyAll()
            await SmartNotificationScheduler.rescheduleForToday(habits: habits)
            WidgetCenter.shared.reloadAllTimelines()
            #if os(iOS)
            PhoneWatchSession.shared.sendSnapshot(habits: habits)
            #endif
        }
        .sheet(isPresented: $showingAddHabit) {
            #if os(iOS)
            NavigationStack { AddHabitView() }
            #else
            AddHabitView()
            #endif
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
}
