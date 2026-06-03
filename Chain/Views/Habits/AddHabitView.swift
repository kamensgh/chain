import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var habit: Habit? = nil

    @State private var name: String
    @State private var emoji: String
    @State private var frequency: Frequency = .daily
    @State private var goalUnit: GoalUnit = .boolean
    @State private var goalTarget: Double = 0
    @State private var connectorType: ConnectorType = .manual
    @State private var connectorEndpoint: String = ""
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var gracePeriodEnabled = false
    @State private var showVerification = false

    init(prefillName: String = "", prefillEmoji: String = "⭐") {
        _name = State(initialValue: prefillName)
        _emoji = State(initialValue: prefillEmoji)
    }

    init(habit: Habit) {
        self.habit = habit
        _name = State(initialValue: habit.name)
        _emoji = State(initialValue: habit.emoji)
        _frequency = State(initialValue: habit.frequency)
        _goalUnit = State(initialValue: habit.goalConfig.unit)
        _goalTarget = State(initialValue: habit.goalConfig.targetValue)
        _connectorType = State(initialValue: habit.connectorType)
        _connectorEndpoint = State(initialValue: habit.connectorEndpoint ?? "")
        _gracePeriodEnabled = State(initialValue: habit.gracePeriodEnabled)
        _reminderEnabled = State(initialValue: habit.reminderTime != nil)
        _reminderTime = State(initialValue: habit.reminderTime ?? Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }

    private var nameIsEmpty: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Name & Icon") {
                HStack(spacing: 12) {
                    TextField("🙂", text: $emoji)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                    TextField("Habit name", text: $name)
                }
            }

            Section("Schedule") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(Frequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue.capitalized).tag(freq)
                    }
                }
            }

            Section("Goal") {
                Picker("Type", selection: $goalUnit) {
                    Text("Done / Not done").tag(GoalUnit.boolean)
                    Text("Steps").tag(GoalUnit.steps)
                    Text("Minutes").tag(GoalUnit.minutes)
                    Text("Custom").tag(GoalUnit.custom)
                }
                .pickerStyle(.segmented)
                if goalUnit != .boolean {
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField("0", value: $goalTarget, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(goalUnit.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Reminder") {
                Toggle("Daily reminder", isOn: $reminderEnabled)
                if reminderEnabled {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }

            Section("Options") {
                Toggle("Grace period", isOn: $gracePeriodEnabled)
                if gracePeriodEnabled {
                    Text("One missed day won't break your streak.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    showVerification = true
                } label: {
                    HStack {
                        Text(habit == nil ? "Continue →" : "Change verification")
                        Spacer()
                        Text(connectorType.displayName)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .disabled(nameIsEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear(perform: loadExisting)
        #if os(iOS)
        .navigationDestination(isPresented: $showVerification) {
            VerificationPickerView(
                connectorType: $connectorType,
                connectorEndpoint: $connectorEndpoint,
                onSave: save
            )
        }
        #else
        .sheet(isPresented: $showVerification) {
            VerificationPickerView(
                connectorType: $connectorType,
                connectorEndpoint: $connectorEndpoint,
                onSave: save
            )
            .frame(minWidth: 420, minHeight: 480)
        }
        #endif
    }

    private func loadExisting() {
        guard let h = habit else { return }
        name = h.name
        emoji = h.emoji
        frequency = h.frequency
        goalUnit = h.goalConfig.unit
        goalTarget = h.goalConfig.targetValue
        connectorType = h.connectorType
        connectorEndpoint = h.connectorEndpoint ?? ""
        gracePeriodEnabled = h.gracePeriodEnabled
        if let t = h.reminderTime {
            reminderEnabled = true
            reminderTime = t
        }
    }

    private func save() {
        let goal = GoalConfig(unit: goalUnit, targetValue: goalTarget, customLabel: "")
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let h = habit {
            h.name = trimmedName
            h.emoji = emoji
            h.frequency = frequency
            h.goalConfig = goal
            h.connectorType = connectorType
            h.connectorEndpoint = connectorType == .mcp ? connectorEndpoint : nil
            h.gracePeriodEnabled = gracePeriodEnabled
            h.reminderTime = reminderEnabled ? reminderTime : nil
            Task { await NotificationScheduler.schedule(for: h) }
        } else {
            let h = Habit(name: trimmedName, emoji: emoji, frequency: frequency, goalConfig: goal)
            h.connectorType = connectorType
            h.connectorEndpoint = connectorType == .mcp ? connectorEndpoint : nil
            h.gracePeriodEnabled = gracePeriodEnabled
            h.reminderTime = reminderEnabled ? reminderTime : nil
            context.insert(h)
            Task { await NotificationScheduler.schedule(for: h) }
        }
        try? context.save()
        dismiss()
    }
}
