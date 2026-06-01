import SwiftUI

enum OnboardingStep {
    case welcome, permissions, firstHabit
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        switch step {
        case .welcome:
            WelcomeStepView { step = .permissions }
        case .permissions:
            PermissionsStepView { step = .firstHabit }
        case .firstHabit:
            FirstHabitStepView(onComplete: onComplete)
        }
    }
}
