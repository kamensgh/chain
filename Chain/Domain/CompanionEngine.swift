// Chain/Domain/CompanionEngine.swift
import Foundation

// MARK: - Types

enum CompanionType: String, Codable, CaseIterable {
    case pet, garden, trophyRoom

    var displayName: String {
        switch self {
        case .pet:        return "Pet"
        case .garden:     return "Garden"
        case .trophyRoom: return "Trophy Room"
        }
    }
}

enum CompanionNeed: Int, CaseIterable {
    case food = 0, water = 1, exercise = 2

    var petLabel: String {
        switch self { case .food: return "Food"; case .water: return "Water"; case .exercise: return "Exercise" }
    }

    var gardenLabel: String {
        switch self { case .food: return "Watering"; case .water: return "Sunlight"; case .exercise: return "Fertilizer" }
    }

    var petEmoji: String {
        switch self { case .food: return "🍖"; case .water: return "🫧"; case .exercise: return "🏃" }
    }

    var gardenEmoji: String {
        switch self { case .food: return "💧"; case .water: return "☀️"; case .exercise: return "🌿" }
    }
}

enum NeedState: Equatable {
    case fed, peckish, hungry, starving, sick

    var isUrgent: Bool { self == .hungry || self == .starving || self == .sick }
}

enum PetStage: String, Codable, CaseIterable {
    case egg, baby, juvenile, adult, legendary

    var xpFloor: Double {
        switch self {
        case .egg:       return 0
        case .baby:      return 50
        case .juvenile:  return 200
        case .adult:     return 500
        case .legendary: return 1000
        }
    }

    var accessoryEmoji: String? {
        switch self {
        case .egg:       return nil
        case .baby:      return "🏷️"
        case .juvenile:  return "🎩"
        case .adult:     return "🎭"
        case .legendary: return "👑"
        }
    }

    var petEmoji: String {
        switch self {
        case .egg:       return "🥚"
        case .baby:      return "🐣"
        case .juvenile:  return "🐱"
        case .adult:     return "😺"
        case .legendary: return "🦁"
        }
    }

    var gardenEmoji: String {
        switch self {
        case .egg:       return "🌱"
        case .baby:      return "🌿"
        case .juvenile:  return "🌳"
        case .adult:     return "🌸"
        case .legendary: return "🌺"
        }
    }
}

enum TrophyTier: Int, CaseIterable {
    case bronze = 7, silver = 14, gold = 30, platinum = 60, diamond = 100

    var emoji: String {
        switch self {
        case .bronze:   return "🥉"
        case .silver:   return "🥈"
        case .gold:     return "🥇"
        case .platinum: return "🏅"
        case .diamond:  return "💎"
        }
    }

    var label: String {
        switch self {
        case .bronze:   return "7-day"
        case .silver:   return "14-day"
        case .gold:     return "30-day"
        case .platinum: return "60-day"
        case .diamond:  return "100-day"
        }
    }
}

struct Trophy: Equatable {
    let tier: TrophyTier
    let habitName: String
}

// MARK: - Engine

enum CompanionEngine {

    static func needState(
        for need: CompanionNeed,
        entries: [StreakEntry],
        frequency: Frequency,
        now: Date
    ) -> NeedState {
        let cal = Calendar.current
        let todayPeriod = HabitScheduler.periodStart(for: frequency, on: now)

        if entries.contains(where: { $0.periodStart == todayPeriod && $0.status == .verified }) {
            return .fed
        }

        let prevDate = cal.date(byAdding: .day, value: -1, to: now)!
        let prevPeriod = HabitScheduler.periodStart(for: frequency, on: prevDate)
        let isPrevDifferentPeriod = prevPeriod != todayPeriod
        let prevVerified = entries.contains { $0.periodStart == prevPeriod && $0.status == .verified }

        if isPrevDifferentPeriod && !prevVerified && !entries.isEmpty {
            return .sick
        }

        guard frequency == .daily else { return .peckish }

        let hour = cal.component(.hour, from: now)
        switch hour {
        case 0..<18: return .peckish
        case 18..<21: return .hungry
        default:     return .starving
        }
    }

    static func stage(xp: Double) -> PetStage {
        switch xp {
        case ..<50:   return .egg
        case ..<200:  return .baby
        case ..<500:  return .juvenile
        case ..<1000: return .adult
        default:      return .legendary
        }
    }

    static func xpDelta(needStates: [NeedState]) -> Double {
        guard !needStates.isEmpty else { return 0 }
        let fedCount = needStates.filter { $0 == .fed }.count
        if fedCount == 0 { return -5 }
        return 5.0 * Double(min(fedCount, 3) + 1)
    }

    static func trophies(
        habits: [(name: String, entries: [StreakEntry], frequency: Frequency)],
        today: Date
    ) -> [Trophy] {
        var result: [Trophy] = []
        for habit in habits {
            let streak = StreakCalculator.current(entries: habit.entries, frequency: habit.frequency, today: today)
            for tier in TrophyTier.allCases where streak >= tier.rawValue {
                result.append(Trophy(tier: tier, habitName: habit.name))
            }
        }
        return result
    }
}
