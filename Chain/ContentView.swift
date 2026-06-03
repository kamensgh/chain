import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List {
                NavigationLink(destination: TodayView()) {
                    Label("Today", systemImage: "house.fill")
                }
                NavigationLink(destination: HabitsListView()) {
                    Label("Habits", systemImage: "target")
                }
                NavigationLink(destination: StatsView()) {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("⛓️ Chain")
        } detail: {
            TodayView()
        }
        .sheet(isPresented: .init(
            get: { !hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        #else
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "house.fill") }
            NavigationStack { HabitsListView() }
                .tabItem { Label("Habits", systemImage: "target") }
            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .fullScreenCover(isPresented: .init(
            get: { !hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        #endif
    }
}
