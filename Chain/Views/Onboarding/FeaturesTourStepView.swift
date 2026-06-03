// Chain/Views/Onboarding/FeaturesTourStepView.swift
import SwiftUI

struct FeaturesTourStepView: View {
    let onNext: () -> Void

    private struct FeatureCard {
        let emoji: String
        let title: String
        let body: String
    }

    private let cards: [FeatureCard] = [
        FeatureCard(
            emoji: "✅",
            title: "Verified automatically",
            body: "Connect to Apple Health, take a screenshot, or use any data source. Chain proves you did it."
        ),
        FeatureCard(
            emoji: "🔥",
            title: "Build unbreakable streaks",
            body: "Every habit you complete extends your chain. Grace periods give you a safety net for off days."
        ),
        FeatureCard(
            emoji: "🐣",
            title: "Your companion grows with you",
            body: "Pick a pet, garden, or trophy room. Complete habits to level it up."
        ),
    ]

    @State private var cardIndex = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $cardIndex) {
                    ForEach(cards.indices, id: \.self) { i in
                        VStack(spacing: 24) {
                            Spacer()
                            Text(cards[i].emoji)
                                .font(.system(size: 72))
                            VStack(spacing: 10) {
                                Text(cards[i].title)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                Text(cards[i].body)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 280)
                            }
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                .tabViewStyle(.automatic)
                #endif
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    ForEach(cards.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == cardIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: i == cardIndex ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: cardIndex)
                    }
                }
                .padding(.bottom, 24)

                Button(cardIndex < cards.count - 1 ? "Next →" : "Continue →") {
                    if cardIndex < cards.count - 1 {
                        withAnimation { cardIndex += 1 }
                    } else {
                        onNext()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
        }
    }
}
