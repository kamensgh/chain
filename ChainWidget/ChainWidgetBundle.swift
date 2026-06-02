import WidgetKit
import SwiftUI

@main
struct ChainWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChainSmallWidget()
        ChainMediumWidget()
        ChainLockScreenWidget()
    }
}
