import SwiftUI

struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                    Text("⛓️")
                        .font(.system(size: 72))
                }

                Text("Chain")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Text("Build habits that stick —\nverified automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .frame(maxWidth: 260)

                Spacer()

                Button("Get Started", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
        }
    }
}
