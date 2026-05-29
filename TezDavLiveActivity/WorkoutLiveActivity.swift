import ActivityKit
import SwiftUI
import WidgetKit

/// The main Live Activity widget that defines Lock Screen and Dynamic Island presentations.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // MARK: — Lock Screen Banner
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(.black.opacity(0.75))
            .activitySystemActionForegroundColor(.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: — Expanded Region
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(attributes: context.attributes)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                // MARK: — Compact Leading
                CompactLeadingView(
                    attributes: context.attributes,
                    state: context.state
                )
            } compactTrailing: {
                // MARK: — Compact Trailing
                CompactTrailingView(
                    attributes: context.attributes,
                    state: context.state
                )
            } minimal: {
                // MARK: — Minimal
                MinimalView(attributes: context.attributes)
            }
        }
    }
}
