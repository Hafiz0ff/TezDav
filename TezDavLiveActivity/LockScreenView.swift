import SwiftUI
import WidgetKit

/// The Lock Screen Live Activity banner showing workout metrics.
struct LockScreenView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        VStack(spacing: 12) {
            if state.isInsideSegment == true, let segmentName = state.segmentName {
                // MARK: — Live Segment Mode
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.yellow)
                    
                    Text(segmentName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(attributes.startTime, style: .timer)
                        .font(.system(size: 14, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                HStack {
                    // Remaining Distance
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f м", state.segmentDistanceRemaining ?? 0.0))
                            .font(.system(size: 22, design: .rounded).weight(.black))
                            .foregroundStyle(.white)
                        Text("осталось")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Time Gap
                    if let gap = state.segmentTimeAheadBehind {
                        let isAhead = gap <= 0
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%@%.1fс", isAhead ? "-" : "+", abs(gap)))
                                .font(.system(size: 22, design: .rounded).weight(.black))
                                .foregroundStyle(isAhead ? Color(red: 1.0, green: 0.48, blue: 0.0) : Color.red)
                            Text(isAhead ? "опережение" : "отставание")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isAhead ? Color(red: 1.0, green: 0.48, blue: 0.0).opacity(0.8) : Color.red.opacity(0.8))
                        }
                    }
                }
            } else {
                // MARK: — Normal Mode
                // MARK: — Header: Sport + Timer
                HStack {
                    Image(systemName: attributes.sportIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                    
                    Text(WorkoutActivityAttributes.displayName(for: attributes.sportType))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Live timer that auto-updates
                    Text(attributes.startTime, style: .timer)
                        .font(.system(size: 15, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.trailing)
                }
                
                // MARK: — Primary Metrics Row
                HStack(spacing: 0) {
                    // Distance
                    MetricCell(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        value: LiveActivityHelpers.formatDistance(state.distanceMeters),
                        unit: "км",
                        color: .white
                    )
                    
                    Spacer()
                    
                    // Pace or Speed
                    if WorkoutActivityAttributes.usesPace(for: attributes.sportType) {
                        MetricCell(
                            icon: "speedometer",
                            value: LiveActivityHelpers.formatPace(state.currentPace),
                            unit: "/км",
                            color: accentColor
                        )
                    } else {
                        MetricCell(
                            icon: "speedometer",
                            value: LiveActivityHelpers.formatSpeed(state.currentSpeed),
                            unit: "км/ч",
                            color: accentColor
                        )
                    }
                    
                    Spacer()
                    
                    // Heart Rate
                    MetricCell(
                        icon: "heart.fill",
                        value: state.heartRate.map { "\($0)" } ?? "—",
                        unit: "уд/м",
                        color: LiveActivityHelpers.heartRateColor(state.heartRate)
                    )
                }
                
                // MARK: — Secondary Metrics Row
                HStack {
                    if let cadence = state.cadence {
                        SecondaryMetric(
                            icon: "metronome",
                            text: "\(cadence) шаг/м"
                        )
                    }
                    
                    Spacer()
                    
                    if let elev = state.elevationGain, elev > 0 {
                        SecondaryMetric(
                            icon: "arrow.up.right",
                            text: String(format: "↑%.0f м", elev)
                        )
                    }
                    
                    Spacer()
                    
                    if let cal = state.calories {
                        SecondaryMetric(
                            icon: "flame.fill",
                            text: "\(cal) ккал"
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var accentColor: Color {
        let lower = attributes.sportType.lowercased()
        if lower.contains("run") { return Color(red: 0.3, green: 0.85, blue: 0.55) }
        if lower.contains("ride") { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        if lower.contains("swim") { return Color(red: 0.3, green: 0.8, blue: 0.9) }
        return Color(red: 0.95, green: 0.65, blue: 0.2)
    }
}

// MARK: — Reusable Metric Cells

private struct MetricCell: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color.opacity(0.8))
            
            Text(value)
                .font(.system(size: 22, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(minWidth: 70)
    }
}

private struct SecondaryMetric: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
