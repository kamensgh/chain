import SwiftUI
import HealthKit

struct PermissionsStepView: View {
    let onNext: () -> Void
    @State private var requesting = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A couple of permissions")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Chain works best with access to these.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 12) {
                    PermissionCard(
                        emoji: "❤️",
                        title: "Health",
                        description: "Reads steps, workouts, sleep, and more to verify habits automatically."
                    )
                    PermissionCard(
                        emoji: "🔔",
                        title: "Notifications",
                        description: "Reminds you to check in and celebrates streak milestones."
                    )
                }

                Spacer()

                Button {
                    Task { await requestPermissions() }
                } label: {
                    if requesting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(requesting)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
        }
    }

    private func requestPermissions() async {
        requesting = true
        if HKHealthStore.isHealthDataAvailable() {
            let readTypes: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.workoutType()
            ]
            try? await HKHealthStore().requestAuthorization(toShare: [], read: readTypes)
        }
        await NotificationScheduler.requestAuthorization()
        requesting = false
        onNext()
    }
}

private struct PermissionCard: View {
    let emoji: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
