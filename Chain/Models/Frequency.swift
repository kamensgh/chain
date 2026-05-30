import Foundation

enum Frequency: String, Codable, CaseIterable {
    case daily, weekly, monthly

    func periodStart(for date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:   return cal.startOfDay(for: date)
        case .weekly:  return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        case .monthly: return cal.dateInterval(of: .month, for: date)?.start ?? cal.startOfDay(for: date)
        }
    }
}
