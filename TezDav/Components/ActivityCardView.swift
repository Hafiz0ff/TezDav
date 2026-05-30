import SwiftUI
import MapKit

/// Activity Card Component - Elevated Depth Style
/// Used in Story Feed for displaying workout summaries
struct ActivityCardView: View {
    let activity: Activity
    @Query private var userSettings: [UserSettings]

    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map Preview
            mapPreview

            // Content
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Title
                Text(activity.name)
                    .font(.title3)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                // Metrics Row
                HStack(spacing: Spacing.md) {
                    metricCard(
                        label: "Дистанция",
                        value: formatDistance(activity.distanceMeters),
                        isAccent: true
                    )

                    metricCard(
                        label: activity.sportType == "Ride" ? "Скорость" : "Темп",
                        value: formatPace(activity.averageSpeed, sportType: activity.sportType),
                        isAccent: false
                    )

                    if let avgHeartRate = activity.averageHeartRate, avgHeartRate > 0 {
                        metricCard(
                            label: "Пульс",
                            value: "\(Int(avgHeartRate))",
                            isAccent: false
                        )
                    }
                }

                // Insight Card (if available)
                if let insight = generateInsight() {
                    insightView(insight)
                }
            }
            .padding(Spacing.lg + 2)
        }
        .elevatedCard()
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            MapPreviewBackground()
                .frame(height: 140)

            // Route path (if available)
            if let coordinates = activity.routeCoordinates, !coordinates.isEmpty {
                RoutePathView(coordinates: coordinates)
                    .frame(height: 140)
            }

            // Date badge
            dateBadge
                .padding(Spacing.md)
        }
        .frame(height: 140)
    }

    private var dateBadge: some View {
        Text(formatDate(activity.startDate))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.black)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color.accentGradient)
            .cornerRadius(CornerRadius.small)
            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 6, x: 0, y: 4)
    }

    // MARK: - Metric Card

    private func metricCard(label: String, value: String, isAccent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.labelSmall)
                .foregroundColor(.textDisabled)
                .tracking(0.5)

            Text(value)
                .font(.metricMedium)
                .foregroundColor(isAccent ? .accentPrimary : .textPrimary)
                .monospacedDigit()
                .shadow(
                    color: isAccent ? Color.accentPrimary.opacity(0.5) : Color.clear,
                    radius: isAccent ? 10 : 0,
                    x: 0,
                    y: 0
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .metricCard(isAccent: isAccent)
    }

    // MARK: - Insight View

    private func insightView(_ insight: String) -> some View {
        HStack(spacing: 8) {
            Text("💡")
                .font(.system(size: 16))

            Text(insight)
                .font(.callout)
                .foregroundColor(.textSecondary)
                .lineLimit(2)
        }
        .padding(Spacing.md)
        .insightCard()
    }

    // MARK: - Helpers

    private func formatDistance(_ meters: Double) -> String {
        if isMetric {
            let km = meters / 1000.0
            return String(format: "%.1f", km)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.1f", miles)
        }
    }

    private func formatPace(_ speedMps: Double, sportType: String) -> String {
        if sportType == "Ride" {
            // Speed for cycling
            if isMetric {
                let kmh = speedMps * 3.6
                return String(format: "%.1f", kmh)
            } else {
                let mph = speedMps * 2.23694
                return String(format: "%.1f", mph)
            }
        } else {
            // Pace for running
            if speedMps <= 0 { return "--:--" }
            let metersPerMinute = speedMps * 60
            let minutesPerKm = 1000.0 / metersPerMinute

            if isMetric {
                let minutes = Int(minutesPerKm)
                let seconds = Int((minutesPerKm - Double(minutes)) * 60)
                return String(format: "%d:%02d", minutes, seconds)
            } else {
                let minutesPerMile = minutesPerKm * 1.60934
                let minutes = Int(minutesPerMile)
                let seconds = Int((minutesPerMile - Double(minutes)) * 60)
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }

    private func generateInsight() -> String? {
        // Simple insight generation
        // TODO: Integrate with AI Coach for better insights
        guard let avgSpeed = activity.averageSpeed, avgSpeed > 0 else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(activity.startDate) {
            return "Отличный темп! Продолжайте в том же духе"
        }

        return nil
    }
}

// MARK: - Route Path View

struct RoutePathView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { geometry in
            if !coordinates.isEmpty {
                Path { path in
                    let bounds = calculateBounds()
                    let points = coordinates.map { coord in
                        normalizeCoordinate(coord, bounds: bounds, size: geometry.size)
                    }

                    if let first = points.first {
                        path.move(to: first)
                        points.dropFirst().forEach { point in
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.accentPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .opacity(0.4)
                .shadow(color: Color.accentPrimary.opacity(0.6), radius: 4, x: 0, y: 0)
            }
        }
    }

    private func calculateBounds() -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    private func normalizeCoordinate(_ coord: CLLocationCoordinate2D, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double), size: CGSize) -> CGPoint {
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2

        let latRange = bounds.maxLat - bounds.minLat
        let lonRange = bounds.maxLon - bounds.minLon

        let x = padding + CGFloat((coord.longitude - bounds.minLon) / lonRange) * availableWidth
        let y = padding + CGFloat((bounds.maxLat - coord.latitude) / latRange) * availableHeight

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Compact Activity Card (for older activities)

struct CompactActivityCardView: View {
    let activity: Activity
    @Query private var userSettings: [UserSettings]

    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(formatDate(activity.startDate) + " • " + formatDistance(activity.distanceMeters))
                    .font(.caption1)
                    .foregroundColor(.textDisabled)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPace(activity.averageSpeed, sportType: activity.sportType))
                    .font(.metricRegular)
                    .foregroundColor(.accentPrimary)
                    .monospacedDigit()

                Text(activity.sportType == "Ride" ? "средняя" : "темп")
                    .font(.caption2)
                    .foregroundColor(.textDisabled)
            }
        }
        .padding(Spacing.md + 2)
        .card()
    }

    private func formatDistance(_ meters: Double) -> String {
        if isMetric {
            let km = meters / 1000.0
            return String(format: "%.1f км", km)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.1f mi", miles)
        }
    }

    private func formatPace(_ speedMps: Double, sportType: String) -> String {
        if sportType == "Ride" {
            if isMetric {
                let kmh = speedMps * 3.6
                return String(format: "%.1f", kmh)
            } else {
                let mph = speedMps * 2.23694
                return String(format: "%.1f", mph)
            }
        } else {
            if speedMps <= 0 { return "--:--" }
            let metersPerMinute = speedMps * 60
            let minutesPerKm = 1000.0 / metersPerMinute

            if isMetric {
                let minutes = Int(minutesPerKm)
                let seconds = Int((minutesPerKm - Double(minutes)) * 60)
                return String(format: "%d:%02d", minutes, seconds)
            } else {
                let minutesPerMile = minutesPerKm * 1.60934
                let minutes = Int(minutesPerMile)
                let seconds = Int((minutesPerMile - Double(minutes)) * 60)
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}
