// Chain/Views/MenuBar/MenuBarIconView.swift
import SwiftUI
import SwiftData

struct MenuBarIconView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var companions: [Companion]

    private var stage: PetStage {
        CompanionEngine.stage(xp: companions.first?.xp ?? 0)
    }

    private var characterEmoji: String {
        guard let companion = companions.first else { return "⛓️" }
        switch companion.companionType {
        case .pet:        return stage.petEmoji
        case .garden:     return stage.gardenEmoji
        case .trophyRoom: return "🏆"
        }
    }

    private var overallState: NeedState {
        guard !habits.isEmpty else { return .fed }
        let states: [NeedState] = CompanionNeed.allCases.prefix(min(habits.count, 3)).map { need in
            let habit = habits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            return CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
        }
        if states.contains(.sick)     { return .sick }
        if states.contains(.starving) { return .starving }
        if states.contains(.hungry)   { return .hungry }
        if states.contains(.peckish)  { return .peckish }
        return .fed
    }

    private var healthDotColor: Color {
        switch overallState {
        case .fed:      return .green
        case .peckish:  return .green.opacity(0.6)
        case .hungry:   return .yellow
        case .starving: return .orange
        case .sick:     return .gray
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(characterEmoji)
                .font(.system(size: 18))
                .colorMultiply(overallState == .sick ? Color(white: 0.6) : .white)
            Circle()
                .fill(healthDotColor)
                .frame(width: 6, height: 6)
        }
    }
}
