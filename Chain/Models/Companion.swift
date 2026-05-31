import SwiftData
import Foundation

@Model
final class Companion {
    var id: UUID = UUID()
    var typeRaw: String = CompanionType.pet.rawValue
    var xp: Double = 0
    var accessoriesUnlocked: [String] = []
    var createdAt: Date = Date.now
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
