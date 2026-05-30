// Chain/Views/Companion/CompanionMenuBarView.swift
import SwiftUI

struct CompanionMenuBarView: View {
    let companion: Companion
    let habits: [Habit]

    private var stage: PetStage { CompanionEngine.stage(xp: companion.xp) }

    private var characterEmoji: String {
        switch companion.companionType {
        case .pet:        return stage.petEmoji
        case .garden:     return stage.gardenEmoji
        case .trophyRoom: return "🏆"
        }
    }

    private var overallState: NeedState {
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
        HStack(spacing: 6) {
            PhaseAnimator([false, true]) { phase in
                Text(characterEmoji)
                    .font(.system(size: 28))
                    .offset(y: phase ? -2 : 2)
                    .colorMultiply(overallState == .sick ? Color(white: 0.6) : .white)
            } animation: { _ in
                .easeInOut(duration: 2.0)
            }

            Circle()
                .fill(healthDotColor)
                .frame(width: 8, height: 8)
        }
    }
}
