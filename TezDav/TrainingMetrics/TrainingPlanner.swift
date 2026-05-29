import Foundation
import SwiftData

struct TrainingPlanner {
    /// Generates and persists the training plan weeks based on user input.
    /// - Parameters:
    ///   - raceDate: Target competition date.
    ///   - currentRunningVolumeMeters: The athlete's current weekly running base volume.
    ///   - currentCyclingHours: The athlete's current weekly cycling hours.
    ///   - modelContext: SwiftData model context.
    @MainActor
    static func generatePlan(
        raceDate: Date,
        currentRunningVolumeMeters: Double,
        currentCyclingHours: Double,
        in modelContext: ModelContext
    ) {
        let calendar = Calendar.current
        let today = Date()
        
        // Find week starts
        guard let todayWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let raceWeekStart = calendar.dateInterval(of: .weekOfYear, for: raceDate)?.start else {
            return
        }
        
        // Count weeks (including the race week itself)
        let components = calendar.dateComponents([.weekOfYear], from: todayWeekStart, to: raceWeekStart)
        let weeksCount = (components.weekOfYear ?? 0) + 1
        
        // We restrict plan generation to range [2, 24] weeks to keep calendar UX high and prevent infinite lists.
        let actualWeeks = max(2, min(24, weeksCount))
        
        // Clean out existing weeks
        try? modelContext.delete(model: TrainingWeek.self)
        
        var peakVolume = currentRunningVolumeMeters > 0 ? currentRunningVolumeMeters : 30000.0 // default 30k
        let baseRun = peakVolume
        let baseBike = currentCyclingHours > 0 ? currentCyclingHours : 3.0 // default 3h
        
        // We will build weeks forward from today's week, labeling them in the cyclic pattern.
        // If we have actualWeeks, the last 2 weeks are Taper weeks (Taper 1, Taper 2/Race).
        let normalWeeksCount = actualWeeks - 2
        
        var generatedWeeks: [TrainingWeek] = []
        
        for w in 0..<actualWeeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: w, to: todayWeekStart) else { continue }
            
            // Format ID: week_YYYY_WW
            let year = calendar.component(.year, from: weekStart)
            let weekNo = calendar.component(.weekOfYear, from: weekStart)
            let id = "week_\(year)_\(weekNo)"
            
            var typeStr = ""
            var runVol = baseRun
            var bikeHours = baseBike
            
            if w == actualWeeks - 1 {
                // Last week: Taper 2 (Race Week)
                typeStr = "Подводящая (тейпер)"
                runVol = peakVolume * 0.50
                bikeHours = baseBike * 0.50
            } else if w == actualWeeks - 2 {
                // Second to last week: Taper 1
                typeStr = "Подводящая"
                runVol = peakVolume * 0.70
                bikeHours = baseBike * 0.70
            } else {
                // Normal cycle: 3:1 pattern (Developing 1 -> Developing 2 -> Peak -> Recovery)
                let cycleIndex = w % 4
                
                if cycleIndex == 0 {
                    typeStr = "Базовая"
                    let mult = 1.0 + Double(w / 4) * 0.10
                    runVol = baseRun * mult
                    bikeHours = baseBike * mult
                } else if cycleIndex == 1 {
                    typeStr = "Развивающая"
                    let mult = 1.1 + Double(w / 4) * 0.10
                    runVol = baseRun * mult
                    bikeHours = baseBike * mult
                } else if cycleIndex == 2 {
                    typeStr = "Ударная"
                    let mult = 1.25 + Double(w / 4) * 0.10
                    runVol = baseRun * mult
                    bikeHours = baseBike * mult
                    // Track maximum volume reached to calculate tapering percentages correctly
                    peakVolume = max(peakVolume, runVol)
                } else {
                    typeStr = "Восстановительная"
                    let mult = 0.65 * (1.0 + Double(w / 4) * 0.08)
                    runVol = baseRun * mult
                    bikeHours = baseBike * mult
                }
            }
            
            let planWeek = TrainingWeek(
                id: id,
                startDate: weekStart,
                typeString: typeStr,
                targetVolumeMeters: round(runVol),
                targetCyclingHours: round(bikeHours * 10.0) / 10.0
            )
            modelContext.insert(planWeek)
            generatedWeeks.append(planWeek)
        }
        
        try? modelContext.save()
    }
}
