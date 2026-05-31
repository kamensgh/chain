import SwiftData
import Foundation

@Model
final class HabitEntry {
    var id: UUID = UUID()
    var periodStart: Date = Date.now
    var statusRaw: String = EntryStatus.pending.rawValue
    var verifMethodRaw: String = VerifMethod.manual.rawValue
    var value: Double?
    var screenshotPath: String?
    var sourceLabel: String?
    var verifiedAt: Date?
    var habit: Habit?

    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var verifMethod: VerifMethod {
        get { VerifMethod(rawValue: verifMethodRaw) ?? .manual }
        set { verifMethodRaw = newValue.rawValue }
    }

    init(habit: Habit, periodStart: Date) {
        self.id = UUID()
        self.periodStart = periodStart
        self.statusRaw = EntryStatus.pending.rawValue
        self.verifMethodRaw = VerifMethod.manual.rawValue
        self.habit = habit
    }
}
