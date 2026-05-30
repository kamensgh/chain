import SwiftData
import Foundation

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var frequencyRaw: String
    var goalConfigData: Data
    var connectorTypeRaw: String
    var connectorEndpoint: String?
    var reminderTime: Date?
    var gracePeriodEnabled: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry] = []

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var goalConfig: GoalConfig {
        get { (try? Self.decoder.decode(GoalConfig.self, from: goalConfigData)) ?? .boolean }
        set {
            goalConfigData = (try? Self.encoder.encode(newValue)) ?? {
                assertionFailure("GoalConfig encoding failed — check Codable conformance")
                return Data()
            }()
        }
    }

    var connectorType: ConnectorType {
        get { ConnectorType(rawValue: connectorTypeRaw) ?? .manual }
        set { connectorTypeRaw = newValue.rawValue }
    }

    init(name: String, emoji: String, frequency: Frequency = .daily, goalConfig: GoalConfig = .boolean) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = ""
        self.frequencyRaw = frequency.rawValue
        self.goalConfigData = (try? JSONEncoder().encode(goalConfig)) ?? {
            assertionFailure("GoalConfig encoding failed in Habit.init")
            return Data()
        }()
        self.connectorTypeRaw = ConnectorType.manual.rawValue
        self.gracePeriodEnabled = false
        self.createdAt = Date()
    }
}
