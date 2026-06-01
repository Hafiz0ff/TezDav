import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Activity Card Component — Liquid Glass styling.
/// Used in Story Feed for displaying workout summaries.
struct ActivityCardView: View {
    let activity: Activity
    @Query private var userSettings: [UserSettings]

    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
            mapPreview
            contentSection
        }
        .liquidGlassCard(cornerRadius: 24, tint: .neutral, glow: false)
    }

    // MARK: - Map Preview Section

    private var mapPreview: some View {
        ZStack(alignment: .topLeading) {
            MapPreviewBackground()
                .frame(height: 150)

            if let poly = activity.encodedPolyline, !poly.isEmpty {
                let coordinates = PolylineEncoder.decode(polyline: poly)
                if !coordinates.isEmpty {
                    RoutePathView(coordinates: coordinates)
                        .frame(height: 150)
                }
            }

            dateBadge
                .padding(14)
        }
        .frame(height: 150)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 24, topTrailing: 24)
            )
        )
    }

    private var dateBadge: some View {
        Text(formatDate(activity.startDate))
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .tracking(0.4)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .liquidGlassPill(isActive: true)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(activity.name)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.textOnGlass)
                .lineLimit(2)

            HStack(spacing: 10) {
                metricChip(
                    label: "Дистанция",
                    value: formatDistance(activity.distanceMeters),
                    isAccent: true
                )

                metricChip(
                    label: activity.sportType == "Ride" ? "Скорость" : "Темп",
                    value: formatPace(activity.averageSpeed ?? 0, sportType: activity.sportType),
                    isAccent: false
                )

                if let avgHeartRate = activity.averageHeartRate, avgHeartRate > 0 {
                    metricChip(
                        label: "Пульс",
                        value: "\(Int(avgHeartRate))",
                        isAccent: false
                    )
                }
            }

            if let insight = generateInsight() {
                insightView(insight)
            }
        }
        .padding(18)
    }

    // MARK: - Metric Chip

    private func metricChip(label: String, value: String, isAccent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.textTertiaryReadable)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(isAccent ? .accentPrimary : .textOnGlass)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(
                    color: isAccent ? Color.accentPrimary.opacity(0.4) : .clear,
                    radius: isAccent ? 12 : 0
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAccent ? Color.glassEmeraldTint : Color.glassNeutralTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isAccent ? Color.accentPrimary.opacity(0.4) : Color.glassBorder,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Insight View

    private func insightView(_ insight: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)

            Text(insight)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondaryReadable)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.glassEmeraldTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentPrimary.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formatDistance(_ meters: Double) -> String {
        let value = isMetric ? meters / 1000.0 : meters / 1609.34
        return String(format: "%.1f", value)
    }

    private func formatPace(_ speedMps: Double, sportType: String) -> String {
        if sportType == "Ride" {
            let value = isMetric ? speedMps * 3.6 : speedMps * 2.23694
            return String(format: "%.1f", value)
        }
        guard speedMps > 0 else { return "--:--" }
        let minutesPerKm = 1000.0 / (speedMps * 60)
        let pace = isMetric ? minutesPerKm : minutesPerKm * 1.60934
        let mins = Int(pace)
        let secs = Int((pace - Double(mins)) * 60)
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Сегодня" }
        if cal.isDateInYesterday(date) { return "Вчера" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func generateInsight() -> String? {
        guard let avgSpeed = activity.averageSpeed, avgSpeed > 0 else { return nil }
        if Calendar.current.isDateInToday(activity.startDate) {
            return "Отличный темп! Продолжайте в том же духе."
        }
        return nil
    }
}

// MARK: - Map Preview Background

struct MapPreviewBackground: View {
    var body: some View {
        ZStack {
            Color.mapPreviewGradient
            // Subtle grain / radial fade for depth
            RadialGradient(
                colors: [Color.black.opacity(0.45), Color.clear],
                center: .bottom,
                startRadius: 20,
                endRadius: 220
            )
        }
    }
}

// MARK: - Route Path View

struct RoutePathView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { geo in
            if !coordinates.isEmpty {
                Path { path in
                    let bounds = calculateBounds()
                    let points = coordinates.map { coord in
                        normalize(coord, bounds: bounds, size: geo.size)
                    }
                    if let first = points.first {
                        path.move(to: first)
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                }
                .stroke(
                    Color.accentPrimary,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.accentPrimary.opacity(0.55), radius: 5)
                .opacity(0.85)
            }
        }
    }

    private func calculateBounds() -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        var minLat = coordinates[0].latitude
        var maxLat = minLat
        var minLon = coordinates[0].longitude
        var maxLon = minLon
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        return (minLat, maxLat, minLon, maxLon)
    }

    private func normalize(
        _ c: CLLocationCoordinate2D,
        bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double),
        size: CGSize
    ) -> CGPoint {
        let pad: CGFloat = 24
        let w = size.width - pad * 2
        let h = size.height - pad * 2
        let latRange = max(bounds.maxLat - bounds.minLat, 0.000001)
        let lonRange = max(bounds.maxLon - bounds.minLon, 0.000001)
        let x = pad + CGFloat((c.longitude - bounds.minLon) / lonRange) * w
        let y = pad + CGFloat((bounds.maxLat - c.latitude) / latRange) * h
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Compact Activity Card (for secondary feed items)

struct CompactActivityCardView: View {
    let activity: Activity
    @Query private var userSettings: [UserSettings]

    private var isMetric: Bool {
        userSettings.first?.isMetric ?? true
    }

    var body: some View {
        HStack(spacing: 14) {
            // Sport icon bubble
            ZStack {
                Circle()
                    .fill(Color.glassEmeraldTint)
                Image(systemName: sportIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            .frame(width: 44, height: 44)
            .overlay(Circle().strokeBorder(Color.accentPrimary.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textOnGlass)
                    .lineLimit(1)

                Text(formatDate(activity.startDate) + " · " + formatDistance(activity.distanceMeters))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textTertiaryReadable)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPace(activity.averageSpeed ?? 0, sportType: activity.sportType))
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentPrimary)
                Text(activity.sportType == "Ride" ? unitSpeedLabel : unitPaceLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textTertiaryReadable)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, tint: .neutral)
    }

    private var sportIcon: String {
        switch activity.sportType.lowercased() {
        case let s where s.contains("ride") || s.contains("cycl"): return "bicycle"
        case let s where s.contains("swim"): return "figure.pool.swim"
        case let s where s.contains("walk") || s.contains("hike"): return "figure.walk"
        default: return "figure.run"
        }
    }

    private var unitPaceLabel: String { isMetric ? "мин/км" : "мин/ми" }
    private var unitSpeedLabel: String { isMetric ? "км/ч" : "ми/ч" }

    private func formatDistance(_ meters: Double) -> String {
        if isMetric {
            return String(format: "%.1f км", meters / 1000.0)
        } else {
            return String(format: "%.1f mi", meters / 1609.34)
        }
    }

    private func formatPace(_ speedMps: Double, sportType: String) -> String {
        if sportType == "Ride" {
            let v = isMetric ? speedMps * 3.6 : speedMps * 2.23694
            return String(format: "%.1f", v)
        }
        guard speedMps > 0 else { return "--:--" }
        let minutesPerKm = 1000.0 / (speedMps * 60)
        let pace = isMetric ? minutesPerKm : minutesPerKm * 1.60934
        let m = Int(pace)
        let s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d", m, s)
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Сегодня" }
        if cal.isDateInYesterday(date) { return "Вчера" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}
