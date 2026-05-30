// Chain/Views/Settings/CompanionSettingsView.swift
import SwiftUI
import SwiftData

struct CompanionSettingsView: View {
    @Query private var companions: [Companion]
    @Environment(\.modelContext) private var context

    private var companion: Companion? { companions.first }

    var body: some View {
        if let companion {
            VStack(alignment: .leading, spacing: 12) {
                Text("Companion Style")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(CompanionType.allCases, id: \.self) { type in
                        typeCard(type, isSelected: companion.companionType == type) {
                            companion.companionType = type
                            try? context.save()
                        }
                    }
                }
            }
        }
    }

    private func typeCard(_ type: CompanionType, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(previewEmoji(for: type))
                    .font(.system(size: 36))
                Text(type.displayName)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func previewEmoji(for type: CompanionType) -> String {
        switch type {
        case .pet:        return "🐱"
        case .garden:     return "🌸"
        case .trophyRoom: return "🏆"
        }
    }
}
