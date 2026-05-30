import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var habit: Habit? = nil         // nil = create new, non-nil = edit existing

    @State private var name = ""
    @State private var emoji = "⭐"
    @State private var frequency: Frequency = .daily
    @State private var goalUnit: GoalUnit = .boolean
    @State private var goalTarget: Double = 0
    @State private var connectorType: ConnectorType = .manual
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var gracePeriodEnabled = false

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

            Section("Verification") {
                Picker("Connect to", selection: $connectorType) {
                    ForEach(ConnectorType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
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
        }
        .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: loadExisting)
    }

    private func loadExisting() {
        guard let h = habit else { return }
        name = h.name
        emoji = h.emoji
        frequency = h.frequency
        goalUnit = h.goalConfig.unit
        goalTarget = h.goalConfig.targetValue
        connectorType = h.connectorType
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
            h.gracePeriodEnabled = gracePeriodEnabled
            h.reminderTime = reminderEnabled ? reminderTime : nil
        } else {
            let h = Habit(name: trimmedName, emoji: emoji, frequency: frequency, goalConfig: goal)
            h.connectorType = connectorType
            h.gracePeriodEnabled = gracePeriodEnabled
            h.reminderTime = reminderEnabled ? reminderTime : nil
            context.insert(h)
        }
        try? context.save()
        dismiss()
    }
}
