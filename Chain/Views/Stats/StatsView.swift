import SwiftUI

struct StatsView: View {
    var body: some View {
        ContentUnavailableView("Stats coming soon", systemImage: "chart.bar.fill",
            description: Text("Streak history and completion rates — coming in a future update."))
            .navigationTitle("Stats")
    }
}
