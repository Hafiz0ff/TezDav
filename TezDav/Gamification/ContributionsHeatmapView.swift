import SwiftUI

struct ContributionsHeatmapView: View {
    let activities: [Activity]
    
    private var dailyTrimpMap: [Date: Double] {
        let calendar = Calendar.current
        var map: [Date: Double] = [:]
        for activity in activities {
            let startOfDay = calendar.startOfDay(for: activity.startDate)
            map[startOfDay, default: 0.0] += activity.trimp
        }
        return map
    }
    
    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Find date 364 days ago (52 weeks)
        guard let startDate = calendar.date(byAdding: .day, value: -364, to: today) else { return [] }
        
        var dates: [Date] = []
        for offset in 0...364 {
            if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                dates.append(calendar.startOfDay(for: date))
            }
        }
        return dates
    }
    
    var body: some View {
        let allDays = days
        let trimpMap = dailyTrimpMap
        let columnsCount = 53
        
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(0..<columnsCount, id: \.self) { colIndex in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { rowIndex in
                                let dayIndex = colIndex * 7 + rowIndex
                                if dayIndex < allDays.count {
                                    let date = allDays[dayIndex]
                                    let trimp = trimpMap[date] ?? 0.0
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(heatmapColor(for: trimp))
                                        .frame(width: 8, height: 8)
                                } else {
                                    Color.clear
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            HStack(spacing: 12) {
                Text(Locale.current.identifier.hasPrefix("ru") ? "Меньше" : "Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 2) {
                    ForEach([0.0, 15.0, 50.0, 110.0, 200.0], id: \.self) { val in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(heatmapColor(for: val))
                            .frame(width: 6, height: 6)
                    }
                }
                
                Text(Locale.current.identifier.hasPrefix("ru") ? "Больше" : "More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func heatmapColor(for trimp: Double) -> Color {
        if trimp == 0 {
            return Color.primary.opacity(0.05)
        } else if trimp < 30 {
            return Color.green.opacity(0.25)
        } else if trimp < 80 {
            return Color.green.opacity(0.5)
        } else if trimp < 150 {
            return Color.green.opacity(0.75)
        } else {
            return Color.green
        }
    }
}
