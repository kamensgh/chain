// Chain/Views/Companion/CompanionCardView.swift
import SwiftUI

struct CompanionCardView: View {
    let companion: Companion
    let habits: [Habit]   // ordered by createdAt — first 3 map to food/water/exercise

    // MARK: - Computed

    private var companionType: CompanionType { companion.companionType }
    private var stage: PetStage { CompanionEngine.stage(xp: companion.xp) }

    private var characterEmoji: String {
        switch companionType {
        case .pet:        return stage.petEmoji
        case .garden:     return stage.gardenEmoji
        case .trophyRoom: return "🏆"
        }
    }

    private var overallState: NeedState {
        let states = activePairs.map { $0.state }
        if states.contains(.sick)     { return .sick }
        if states.contains(.starving) { return .starving }
        if states.contains(.hungry)   { return .hungry }
        if states.contains(.peckish)  { return .peckish }
        return .fed
    }

    private struct NeedPair: Identifiable {
        let id: Int
        let need: CompanionNeed
        let state: NeedState
    }

    private var activePairs: [NeedPair] {
        CompanionNeed.allCases.prefix(min(habits.count, 3)).map { need in
            let habit = habits[need.rawValue]
            let entries = habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) }
            let state = CompanionEngine.needState(for: need, entries: entries, frequency: habit.frequency, now: Date())
            return NeedPair(id: need.rawValue, need: need, state: state)
        }
    }

    private var xpProgress: Double {
        let all = PetStage.allCases
        guard let idx = all.firstIndex(of: stage), idx + 1 < all.count else { return 1 }
        let nextFloor = all[idx + 1].xpFloor
        let range = nextFloor - stage.xpFloor
        return range > 0 ? (companion.xp - stage.xpFloor) / range : 1
    }

    private var trophyItems: [Trophy] {
        guard companionType == .trophyRoom else { return [] }
        let habitData = habits.map { habit in
            (
                name: habit.name,
                entries: habit.entries.map { StreakEntry(periodStart: $0.periodStart, status: $0.status) },
                frequency: habit.frequency
            )
        }
        return CompanionEngine.trophies(habits: habitData, today: Date())
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {
            characterSection
            if companionType == .trophyRoom {
                trophySection
            } else {
                xpBarSection
                needIndicatorsSection
                growthPromptSection
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Subviews

    private var characterSection: some View {
        PhaseAnimator([false, true]) { phase in
            ZStack(alignment: .topTrailing) {
                Text(characterEmoji)
                    .font(.system(size: 72))
                    .offset(y: phase ? -4 : 4)
                    .colorMultiply(overallState == .sick ? Color(white: 0.55) : .white)
                    .overlay(alignment: .topTrailing) {
                        if let accessory = stage.accessoryEmoji {
                            Text(accessory)
                                .font(.system(size: 26))
                                .offset(x: 6, y: -6)
                        }
                    }

                if overallState == .sick {
                    Text("🤒")
                        .font(.system(size: 26))
                        .offset(x: -2, y: -8)
                }
            }
        } animation: { _ in
            .easeInOut(duration: 1.8)
        }
    }

    private var xpBarSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text(stage.rawValue.capitalized)
                    .font(.caption.bold())
                Spacer()
                Text("\(Int(companion.xp)) XP")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * min(max(xpProgress, 0), 1), height: 6)
                        .animation(.spring(response: 0.5), value: companion.xp)
                }
            }
            .frame(height: 6)
        }
    }

    private var needIndicatorsSection: some View {
        HStack(spacing: 20) {
            ForEach(activePairs) { pair in
                VStack(spacing: 4) {
                    Text(pair.state == .fed ? "✅" : pair.state == .sick ? "🤒" : pair.need.petEmoji)
                        .font(.title3)
                    Text(companionType == .garden ? pair.need.gardenLabel : pair.need.petLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var growthPromptSection: some View {
        if habits.count < 3, let nextNeed = CompanionNeed.allCases[safe: habits.count] {
            let label = companionType == .garden ? nextNeed.gardenLabel : nextNeed.petLabel
            Text("Add a \(label) habit to grow faster! ➕")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var trophySection: some View {
        Group {
            if trophyItems.isEmpty {
                Text("Complete habits to earn trophies 🏆")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(trophyItems.prefix(9).enumerated()), id: \.offset) { _, trophy in
                        VStack(spacing: 2) {
                            Text(trophy.tier.emoji).font(.title2)
                            Text(trophy.tier.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// Safe subscript helper to avoid index-out-of-bounds in the growth prompt
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
