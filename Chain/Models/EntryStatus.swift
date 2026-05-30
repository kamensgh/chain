import Foundation

enum EntryStatus: String, Codable {
    case pending, verified, skipped
}

enum VerifMethod: String, Codable {
    case auto, screenshot, manual
}
