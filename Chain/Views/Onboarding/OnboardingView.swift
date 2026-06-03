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
            #if os(iOS)
            WelcomeStepView { step = .permissions }
            #else
            WelcomeStepView { step = .firstHabit }
            #endif
        case .permissions:
            #if os(iOS)
            PermissionsStepView { step = .firstHabit }
            #else
            FirstHabitStepView(onComplete: onComplete)
            #endif
        case .firstHabit:
            FirstHabitStepView(onComplete: onComplete)
        }
    }
}
