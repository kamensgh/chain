import Foundation

enum GoalUnit: String, Codable, CaseIterable {
    case boolean, steps, minutes, custom
}

struct GoalConfig: Codable {
    var unit: GoalUnit
    var targetValue: Double
    var customLabel: String

    static let boolean = GoalConfig(unit: .boolean, targetValue: 0, customLabel: "")

    static func steps(_ count: Double) -> GoalConfig {
        GoalConfig(unit: .steps, targetValue: count, customLabel: "")
    }

    static func minutes(_ count: Double) -> GoalConfig {
        GoalConfig(unit: .minutes, targetValue: count, customLabel: "")
    }

    static func custom(label: String, target: Double) -> GoalConfig {
        GoalConfig(unit: .custom, targetValue: target, customLabel: label)
    }
}
