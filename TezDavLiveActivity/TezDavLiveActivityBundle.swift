import SwiftUI
import WidgetKit

@main
struct TezDavLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
        TezSyncLiveActivity()
    }
}
