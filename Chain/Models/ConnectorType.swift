import Foundation

enum ConnectorType: String, Codable, CaseIterable {
    case manual
    case healthKitSteps
    case healthKitWorkout
    case healthKitSleep
    case screenshot
    case mcp

    var displayName: String {
        switch self {
        case .manual:           return "Manual check-in"
        case .healthKitSteps:   return "Apple Health – Steps"
        case .healthKitWorkout: return "Apple Health – Workout"
        case .healthKitSleep:   return "Apple Health – Sleep"
        case .screenshot:       return "Screenshot proof"
        case .mcp:              return "MCP server"
        }
    }
}
