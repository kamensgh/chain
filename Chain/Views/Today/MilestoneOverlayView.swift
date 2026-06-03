import SwiftUI

struct MilestoneCelebration: Identifiable {
    let id = UUID()
    let habit: Habit
    let streak: Int
}

struct MilestoneOverlayView: View {
    let habit: Habit
    let streak: Int
    let onDismiss: () -> Void

    @State private var animating = false

    private let particles: [(emoji: String, x: CGFloat, delay: Double)] = {
        let emojis = ["🎉", "⭐", "🔥", "✨", "💫"]
        return (0..<20).map { i in
            (emoji: emojis[i % emojis.count],
             x: CGFloat(i) / 19.0,
             delay: Double(i) * 0.08)
        }
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(0..<particles.count, id: \.self) { i in
                    Text(particles[i].emoji)
                        .font(.title)
                        .position(
                            x: particles[i].x * geo.size.width,
                            y: animating ? geo.size.height + 60 : -60
                        )
                        .animation(
                            .easeOut(duration: 1.8).delay(particles[i].delay),
                            value: animating
                        )
                }
            }

            VStack(spacing: 12) {
                Text("🔥")
                    .font(.system(size: 64))
                    .scaleEffect(animating ? 1.2 : 0.6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: animating)

                Text("\(streak)-day streak!")
                    .font(.title.bold())

                Text("\(habit.emoji) \(habit.name) is on fire!")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Keep it up!") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear { animating = true }
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
    }
}
