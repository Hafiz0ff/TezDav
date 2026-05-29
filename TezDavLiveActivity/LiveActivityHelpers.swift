import SwiftUI

/// Formatting helpers used by both Lock Screen and Dynamic Island views.
enum LiveActivityHelpers {
    
    // MARK: — Distance Formatting
    
    /// Formats distance in meters to a human-readable km string.
    /// Under 1 km: shows meters (e.g. "850 м" → "0.85")
    /// 1–99 km: one decimal (e.g. "5.2")
    /// 100+ km: no decimal (e.g. "142")
    static func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        if km < 10 {
            return String(format: "%.2f", km)
        } else if km < 100 {
            return String(format: "%.1f", km)
        } else {
            return String(format: "%.0f", km)
        }
    }
    
    // MARK: — Pace Formatting
    
    /// Formats pace from seconds-per-km to "M:SS" string.
    /// Returns "—" if nil or zero.
    static func formatPace(_ secondsPerKm: Double?) -> String {
        guard let pace = secondsPerKm, pace > 0 else { return "—" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: — Speed Formatting
    
    /// Formats speed in km/h to one decimal place.
    /// Returns "—" if nil or zero.
    static func formatSpeed(_ kmh: Double?) -> String {
        guard let speed = kmh, speed > 0 else { return "—" }
        return String(format: "%.1f", speed)
    }
    
    // MARK: — Elapsed Time Formatting
    
    /// Formats elapsed seconds to "H:MM:SS" or "MM:SS".
    static func formatElapsed(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: — Heart Rate Zone Color
    
    /// Returns a color based on heart rate zone.
    /// Uses standard 5-zone model (assuming max HR ~190).
    static func heartRateColor(_ hr: Int?) -> Color {
        guard let hr = hr else { return .gray }
        switch hr {
        case ..<120:
            return Color(red: 0.4, green: 0.8, blue: 0.4)   // Zone 1 — green
        case 120..<140:
            return Color(red: 0.3, green: 0.85, blue: 0.55)  // Zone 2 — bright green
        case 140..<155:
            return Color(red: 1.0, green: 0.85, blue: 0.2)   // Zone 3 — yellow
        case 155..<170:
            return Color(red: 1.0, green: 0.55, blue: 0.2)   // Zone 4 — orange
        default:
            return Color(red: 1.0, green: 0.3, blue: 0.3)    // Zone 5 — red
        }
    }
    
    // MARK: — Cadence Label
    
    /// Returns the appropriate cadence unit label for the sport type.
    static func cadenceUnit(for sportType: String) -> String {
        let lower = sportType.lowercased()
        if lower.contains("run") || lower.contains("walk") { return "шаг/м" }
        if lower.contains("ride") || lower.contains("cycl") { return "об/м" }
        return "уд/м"
    }
}
