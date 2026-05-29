import Charts
import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Environment(\.modelContext) private var modelContext
    
    // Riegel Calculator state
    @State private var baselineDistance: Double = 10000.0 // Default 10k
    @State private var baselineHours: Int = 0
    @State private var baselineMinutes: Int = 48
    @State private var baselineSeconds: Int = 0
    
    // Dynamic progression chart selection
    @State private var selectedRunningProgressDistance: String = "5k"

    var body: some View {
        NavigationStack {
            Group {
                let runningActivities = activities.filter { $0.sportType.lowercased().contains("run") }
                
                if runningActivities.isEmpty {
                    ContentUnavailableView(
                        "Нет рекордов",
                        systemImage: "trophy",
                        description: Text("Синхронизируй хотя бы одну беговую тренировку чтобы увидеть рекорды")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Running Personal Records
                            runningRecordsSection
                            
                            // Dynamic Record Progression Chart
                            recordProgressionSection

                            // Cycling Critical Power Curve
                            cyclingCriticalPowerSection
                            
                            // Riegel Race Predictor Calculator
                            racePredictorSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Records & Projections")
            .onAppear {
                scanAndComputeRecords()
            }
        }
    }

    // MARK: - Running Personal Records Section
    private var runningRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Running Personal Records")
                .font(.headline)

            let distances: [(name: String, keyPath: KeyPath<Activity, TimeInterval?>)] = [
                ("1 km", \Activity.best1kTime),
                ("5 km", \Activity.best5kTime),
                ("10 km", \Activity.best10kTime),
                ("Half Marathon", \Activity.bestHalfMarathonTime),
                ("Marathon", \Activity.bestMarathonTime)
            ]

            VStack(spacing: 0) {
                ForEach(distances, id: \.name) { dist in
                    let bestPair = findBestRecord(for: dist.keyPath)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dist.name)
                                .font(.subheadline.weight(.semibold))
                            if let act = bestPair.activity {
                                Text(act.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let time = bestPair.time, let act = bestPair.activity {
                            NavigationLink(destination: ActivityDetailView(activity: act)) {
                                HStack(spacing: 4) {
                                    Text(formattedDuration(time))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("--:--")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    if dist.name != "Marathon" {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Dynamic Record Progression Chart Section
    private var recordProgressionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Record History")
                    .font(.headline)
                Spacer()
                Picker("Distance", selection: $selectedRunningProgressDistance) {
                    Text("1k").tag("1k")
                    Text("5k").tag("5k")
                    Text("10k").tag("10k")
                }
                .pickerStyle(.menu)
            }

            let progressData = makeProgressionData()
            if progressData.isEmpty {
                Text("Complete activities of this distance with GPS to see history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(progressData) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Pace", point.value / 60.0) // Plot in minutes
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Pace", point.value / 60.0)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 120)
                    .chartYAxis {
                        AxisMarks(values: .automatic) { value in
                            if let mins = value.as(Double.self) {
                                AxisValueLabel(String(format: "%.0f:00", mins))
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Cycling Critical Power Section
    private var cyclingCriticalPowerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Critical Power Curve")
                .font(.headline)
            
            let powerCurves: [(duration: String, keyPath: KeyPath<Activity, Double?>)] = [
                ("5 sec", \Activity.peakPower5s),
                ("1 min", \Activity.peakPower1m),
                ("5 min", \Activity.peakPower5m),
                ("20 min", \Activity.peakPower20m),
                ("60 min", \Activity.peakPower60m)
            ]
            
            let hasAnyPower = activities.contains { $0.peakPower5s != nil }
            if !hasAnyPower {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.slash")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No cycling power records found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 8) {
                    ForEach(powerCurves, id: \.duration) { cp in
                        let peakPower = activities.compactMap { $0[keyPath: cp.keyPath] }.max() ?? 0.0
                        
                        VStack(spacing: 6) {
                            Text(cp.duration)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(peakPower > 0 ? String(format: "%.0fW", peakPower) : "--")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Riegel Race Predictor Section
    private var racePredictorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Race Time Predictor")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // Baseline Picker
                HStack {
                    Text("Based on:")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("Baseline Distance", selection: $baselineDistance) {
                        Text("1 km").tag(1000.0)
                        Text("5 km").tag(5000.0)
                        Text("10 km").tag(10000.0)
                        Text("Half Marathon").tag(21097.0)
                    }
                    .pickerStyle(.menu)
                }
                
                // Baseline Time Picker (hours, minutes, seconds)
                HStack {
                    Text("Baseline Time:")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Picker("Hours", selection: $baselineHours) {
                            ForEach(0..<10) { h in
                                Text("\(h)h").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 60)
                        .clipped()
                        
                        Picker("Minutes", selection: $baselineMinutes) {
                            ForEach(0..<60) { m in
                                Text("\(m)m").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 55, height: 60)
                        .clipped()
                        
                        Picker("Seconds", selection: $baselineSeconds) {
                            ForEach(0..<60) { s in
                                Text("\(s)s").tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 60)
                        .clipped()
                    }
                }
                .padding(.vertical, -8)
                
                Divider()
                
                // Predictions table
                let baselineSec = Double(baselineHours * 3600 + baselineMinutes * 60 + baselineSeconds)
                if baselineSec <= 0 {
                    Text("Enter a valid baseline time to see projections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let targets = [
                        (name: "5 km", dist: 5000.0),
                        (name: "10 km", dist: 10000.0),
                        (name: "Half Marathon", dist: 21097.0),
                        (name: "Marathon", dist: 42195.0)
                    ]
                    
                    VStack(spacing: 8) {
                        ForEach(targets, id: \.name) { target in
                            // Do not project baseline itself
                            if abs(target.dist - baselineDistance) > 10 {
                                let projectedSec = baselineSec * pow(target.dist / baselineDistance, 1.06)
                                HStack {
                                    Text(target.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(formattedDuration(projectedSec))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helper Methods & Algorithms

    private func findBestRecord(for keyPath: KeyPath<Activity, TimeInterval?>) -> (time: TimeInterval?, activity: Activity?) {
        let sortedPairs = activities.filter { $0[keyPath: keyPath] != nil }
        guard let bestAct = sortedPairs.min(by: { $0[keyPath: keyPath]! < $1[keyPath: keyPath]! }) else {
            return (nil, nil)
        }
        return (bestAct[keyPath: keyPath], bestAct)
    }

    struct ProgressionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func makeProgressionData() -> [ProgressionPoint] {
        let keyPath: KeyPath<Activity, TimeInterval?> = {
            switch selectedRunningProgressDistance {
            case "1k": return \Activity.best1kTime
            case "10k": return \Activity.best10kTime
            default: return \Activity.best5kTime
            }
        }()
        
        let validActs = activities.filter { $0[keyPath: keyPath] != nil }.sorted { $0.startDate < $1.startDate }
        guard !validActs.isEmpty else { return [] }
        
        var points: [ProgressionPoint] = []
        var bestSoFar = Double.infinity
        
        for act in validActs {
            if let val = act[keyPath: keyPath], val < bestSoFar {
                bestSoFar = val
                points.append(ProgressionPoint(date: act.startDate, value: val))
            }
        }
        
        return points
    }

    private func scanAndComputeRecords() {
        // Runs dynamic check on appear to scan SwiftData and calculate missing splits if streams are present
        Task {
            let runToScan = activities.filter { $0.sportType.lowercased().contains("run") && $0.best1kTime == nil && $0.streamsImported }
            let rideToScan = activities.filter { $0.sportType.lowercased().contains("ride") && $0.peakPower5s == nil && $0.streamsImported }
            
            let totalToScan = runToScan + rideToScan
            guard !totalToScan.isEmpty else { return }
            
            var newRecordsFound = false
            for act in totalToScan {
                let actId = act.stravaId
                let descriptor = FetchDescriptor<ActivityStreamSample>(
                    predicate: #Predicate { $0.activityId == actId }
                )
                if let samples = try? modelContext.fetch(descriptor), !samples.isEmpty {
                    PersonalRecordCalculator.calculateAndSetRecords(for: act, samples: samples)
                    newRecordsFound = true
                }
            }
            
            try? modelContext.save()
            
            if newRecordsFound {
                HapticManager.trigger(.medium)
            }
            
            // Set Riegel baseline time automatically based on best 10k (if exists)
            let best10k = findBestRecord(for: \Activity.best10kTime)
            if let best10kTime = best10k.time {
                let hours = Int(best10kTime) / 3600
                let minutes = (Int(best10kTime) % 3600) / 60
                let seconds = Int(best10kTime) % 60
                
                await MainActor.run {
                    self.baselineDistance = 10000.0
                    self.baselineHours = hours
                    self.baselineMinutes = minutes
                    self.baselineSeconds = seconds
                }
            }
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
