import SwiftUI

enum OnboardingStep {
    case welcome, featureTour, companionPick, permissions, firstHabit
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        switch step {
        case .welcome:
            WelcomeStepView { step = .featureTour }
        case .featureTour:
            FeaturesTourStepView { step = .companionPick }
        case .companionPick:
            #if os(iOS)
            CompanionPickerStepView { step = .permissions }
            #else
            CompanionPickerStepView { step = .firstHabit }
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
