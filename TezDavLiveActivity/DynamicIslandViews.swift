import SwiftUI
import WidgetKit

// MARK: — Compact Leading (DI left pill)

struct CompactLeadingView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attributes.sportIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(sportColor)
            
            Text(LiveActivityHelpers.formatDistance(state.distanceMeters))
                .font(.system(size: 13, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
    
    private var sportColor: Color {
        let lower = attributes.sportType.lowercased()
        if lower.contains("run") { return Color(red: 0.3, green: 0.85, blue: 0.55) }
        if lower.contains("ride") { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        return Color(red: 0.95, green: 0.65, blue: 0.2)
    }
}

// MARK: — Compact Trailing (DI right pill)

struct CompactTrailingView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        Text(attributes.startTime, style: .timer)
            .font(.system(size: 13, design: .monospaced).weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 42)
    }
}

// MARK: — Minimal (single small circle)

struct MinimalView: View {
    let attributes: WorkoutActivityAttributes
    
    var body: some View {
        Image(systemName: attributes.sportIcon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(sportColor)
    }
    
    private var sportColor: Color {
        let lower = attributes.sportType.lowercased()
        if lower.contains("run") { return Color(red: 0.3, green: 0.85, blue: 0.55) }
        if lower.contains("ride") { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        return Color(red: 0.95, green: 0.65, blue: 0.2)
    }
}

// MARK: — Expanded Leading

struct ExpandedLeadingView: View {
    let attributes: WorkoutActivityAttributes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: attributes.sportIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(sportColor)
            
            Text(WorkoutActivityAttributes.displayName(for: attributes.sportType))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var sportColor: Color {
        let lower = attributes.sportType.lowercased()
        if lower.contains("run") { return Color(red: 0.3, green: 0.85, blue: 0.55) }
        if lower.contains("ride") { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        return Color(red: 0.95, green: 0.65, blue: 0.2)
    }
}

// MARK: — Expanded Trailing

struct ExpandedTrailingView: View {
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(LiveActivityHelpers.heartRateColor(state.heartRate))
                
                Text(state.heartRate.map { "\($0)" } ?? "—")
                    .font(.system(size: 18, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            
            Text("уд/мин")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: — Expanded Center

struct ExpandedCenterView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        HStack(spacing: 16) {
            // Distance
            VStack(spacing: 1) {
                Text(LiveActivityHelpers.formatDistance(state.distanceMeters))
                    .font(.system(size: 20, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                
                Text("км")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Divider
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 28)
            
            // Pace or Speed
            VStack(spacing: 1) {
                if WorkoutActivityAttributes.usesPace(for: attributes.sportType) {
                    Text(LiveActivityHelpers.formatPace(state.currentPace))
                        .font(.system(size: 20, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    
                    Text("/км")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text(LiveActivityHelpers.formatSpeed(state.currentSpeed))
                        .font(.system(size: 20, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    
                    Text("км/ч")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}

// MARK: — Expanded Bottom

struct ExpandedBottomView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        HStack {
            // Timer
            HStack(spacing: 3) {
                Image(systemName: "timer")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text(attributes.startTime, style: .timer)
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Cadence
            if let cadence = state.cadence {
                HStack(spacing: 3) {
                    Image(systemName: "metronome")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("\(cadence)")
                        .font(.system(size: 12, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Elevation
            if let elev = state.elevationGain, elev > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(String(format: "%.0f м", elev))
                        .font(.system(size: 12, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
