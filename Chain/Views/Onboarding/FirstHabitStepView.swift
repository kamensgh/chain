import SwiftUI
import SwiftData

struct FirstHabitStepView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var frequency: Frequency = .daily

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your first habit")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("You can add more later.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("⭐")
                            .font(.title2)
                            .frame(width: 40)
                        ZStack(alignment: .leading) {
                            if name.isEmpty {
                                Text("e.g. Walk 10k steps")
                                    .foregroundStyle(.white.opacity(0.3))
                                    .font(.body)
                            }
                            TextField("", text: $name)
                                .foregroundStyle(.white)
                                .font(.body)
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HOW OFTEN?")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 2)
                        Picker("Frequency", selection: $frequency) {
                            ForEach(Frequency.allCases, id: \.self) { f in
                                Text(f.rawValue.capitalized).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button("Start My Streak →") {
                    createHabitAndFinish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(trimmedName.isEmpty)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
        }
    }

    private func createHabitAndFinish() {
        guard !trimmedName.isEmpty else { return }
        let habit = Habit(name: trimmedName, emoji: "⭐", frequency: frequency)
        modelContext.insert(habit)
        try? modelContext.save()
        onComplete()
    }
}
