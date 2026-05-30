// Chain/Models/Companion.swift
import SwiftData
import Foundation

@Model
final class Companion {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var xp: Double
    var accessoriesUnlocked: [String]   // PetStage raw values the companion has reached (never shrinks)
    var createdAt: Date
    var lastXPDate: Date?

    var companionType: CompanionType {
        get { CompanionType(rawValue: typeRaw) ?? .pet }
        set { typeRaw = newValue.rawValue }
    }

    init(type: CompanionType = .pet) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.xp = 0
        self.accessoriesUnlocked = []
        self.createdAt = Date()
    }

    /// Adds XP, clamps to stage floor, unlocks accessories for newly reached stages.
    /// Returns the newly unlocked PetStage if a stage transition occurred, nil otherwise.
    @discardableResult
    func applyXP(_ delta: Double) -> PetStage? {
        let oldStage = CompanionEngine.stage(xp: xp)
        xp = max(oldStage.xpFloor, xp + delta)
        let newStage = CompanionEngine.stage(xp: xp)
        if newStage != oldStage && !accessoriesUnlocked.contains(newStage.rawValue) {
            accessoriesUnlocked.append(newStage.rawValue)
            return newStage
        }
        return nil
    }
}
