import SwiftUI

enum StatsTab: String, CaseIterable, Identifiable {
    case streaks  = "Streaks"
    case summary  = "Summary"
    case calendar = "Calendar"
    var id: String { rawValue }
}

struct StatsView: View {
    @State private var selectedTab: StatsTab = .streaks

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(StatsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            switch selectedTab {
            case .streaks:  StreaksTabView()
            case .summary:  SummaryTabView()
            case .calendar: CalendarTabView()
            }
        }
        .navigationTitle("Stats")
    }
}
