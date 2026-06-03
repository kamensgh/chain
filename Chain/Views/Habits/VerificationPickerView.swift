// Chain/Views/Habits/VerificationPickerView.swift
import SwiftUI

struct VerificationPickerView: View {
    @Binding var connectorType: ConnectorType
    @Binding var connectorEndpoint: String
    let onSave: () -> Void

    private enum HealthDataType: String, CaseIterable {
        case steps = "Steps"
        case workout = "Workout mins"
        case sleep = "Sleep hours"

        var connectorType: ConnectorType {
            switch self {
            case .steps:   return .healthKitSteps
            case .workout: return .healthKitWorkout
            case .sleep:   return .healthKitSleep
            }
        }

        static func from(_ type: ConnectorType) -> HealthDataType? {
            switch type {
            case .healthKitSteps:   return .steps
            case .healthKitWorkout: return .workout
            case .healthKitSleep:   return .sleep
            default: return nil
            }
        }
    }

    private enum CardChoice { case manual, health, screenshot, mcp }

    @State private var cardChoice: CardChoice = .manual
    @State private var healthDataType: HealthDataType = .steps

    private var isHealthSelected: Bool { cardChoice == .health }
    private var isMCPSelected: Bool { cardChoice == .mcp }

    private var saveDisabled: Bool {
        isMCPSelected && (
            connectorEndpoint.trimmingCharacters(in: .whitespaces).isEmpty ||
            URL(string: connectorEndpoint) == nil
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    cardRow(
                        choice: .manual,
                        emoji: "✋",
                        title: "Manual",
                        subtitle: "Tap to mark done yourself"
                    )

                    #if os(iOS)
                    cardRow(
                        choice: .health,
                        emoji: "❤️",
                        title: "Apple Health",
                        subtitle: "Steps, workouts, sleep — auto-verified"
                    )

                    if isHealthSelected {
                        Picker("Health data", selection: $healthDataType) {
                            ForEach(HealthDataType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    cardRow(
                        choice: .screenshot,
                        emoji: "📸",
                        title: "Screenshot",
                        subtitle: "Upload a photo as proof"
                    )
                    #endif

                    cardRow(
                        choice: .mcp,
                        emoji: "🔌",
                        title: "MCP / Custom",
                        subtitle: "Connect any data source via URL"
                    )

                    if isMCPSelected {
                        TextField("https://example.com/verify", text: $connectorEndpoint)
                            #if os(iOS)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
                .animation(.spring(response: 0.3), value: cardChoice)
            }

            Divider()
            Button("Save", action: commitAndSave)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(saveDisabled)
                .frame(maxWidth: .infinity)
                .padding(16)
        }
        .navigationTitle("How will you verify it?")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { syncFromBinding() }
    }

    @ViewBuilder
    private func cardRow(choice: CardChoice, emoji: String, title: String, subtitle: String) -> some View {
        let isSelected = cardChoice == choice
        Button {
            withAnimation(.spring(response: 0.3)) { cardChoice = choice }
        } label: {
            HStack(spacing: 14) {
                Text(emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func syncFromBinding() {
        switch connectorType {
        case .manual:           cardChoice = .manual
        case .mcp:              cardChoice = .mcp
        case .healthKitSteps:   cardChoice = .health; healthDataType = .steps
        case .healthKitWorkout: cardChoice = .health; healthDataType = .workout
        case .healthKitSleep:   cardChoice = .health; healthDataType = .sleep
        #if os(iOS)
        case .screenshot:       cardChoice = .screenshot
        #else
        case .screenshot:       cardChoice = .manual
        #endif
        }
    }

    private func commitAndSave() {
        switch cardChoice {
        case .manual:     connectorType = .manual
        case .screenshot: connectorType = .screenshot
        case .mcp:        connectorType = .mcp
        case .health:     connectorType = healthDataType.connectorType
        }
        if connectorType != .mcp { connectorEndpoint = "" }
        onSave()
    }
}
