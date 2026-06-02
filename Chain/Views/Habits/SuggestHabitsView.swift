#if os(iOS)
import SwiftUI

private enum SuggestionState {
    case loading
    case loaded([SuggestedHabit], offline: Bool)
    case failed
}

struct SuggestHabitsView: View {
    let existingNames: [String]
    let onSelect: (SuggestedHabit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: SuggestionState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Thinking…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let suggestions, let offline):
                List {
                    ForEach(suggestions.indices, id: \.self) { i in
                        let suggestion = suggestions[i]
                        HStack(spacing: 12) {
                            Text(suggestion.emoji)
                                .font(.title2)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                    .font(.headline)
                                Text(suggestion.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                onSelect(suggestion)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                    if offline {
                        Text("Suggestions generated offline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }

            case .failed:
                VStack(spacing: 16) {
                    Text("Couldn't generate suggestions.")
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await load() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Suggested Habits")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let result = try await HabitSuggestionService.shared.suggest(existingNames: existingNames)
            state = .loaded(result.habits, offline: result.offline)
        } catch {
            state = .failed
        }
    }
}
#endif
