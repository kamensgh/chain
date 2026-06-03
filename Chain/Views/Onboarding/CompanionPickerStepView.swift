// Chain/Views/Onboarding/CompanionPickerStepView.swift
import SwiftUI
import SwiftData

struct CompanionPickerStepView: View {
    let onNext: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var companions: [Companion]

    @State private var selected: CompanionType = .pet

    private struct CompanionOption {
        let type: CompanionType
        let emoji: String
        let arc: String
    }

    private let options: [CompanionOption] = [
        CompanionOption(type: .pet,        emoji: "🐣", arc: "Egg → Baby → Juvenile → Adult → Legendary"),
        CompanionOption(type: .garden,     emoji: "🌱", arc: "Seedling → Sapling → Shrub → Tree → Ancient"),
        CompanionOption(type: .trophyRoom, emoji: "🏆", arc: "Collect trophies for every milestone"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose your companion")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("It grows as you build habits.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 12) {
                    ForEach(options, id: \.type) { option in
                        optionRow(option)
                    }
                }

                Spacer()

                Button("Let's go →") {
                    saveSelection()
                    onNext()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
        }
    }

    @ViewBuilder
    private func optionRow(_ option: CompanionOption) -> some View {
        let isSelected = selected == option.type
        Button {
            selected = option.type
        } label: {
            HStack(spacing: 14) {
                Text(option.emoji)
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.type.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(option.arc)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.white.opacity(0.15))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func saveSelection() {
        if let companion = companions.first {
            companion.companionType = selected
        } else {
            let companion = Companion(type: selected)
            context.insert(companion)
        }
        try? context.save()
    }
}
