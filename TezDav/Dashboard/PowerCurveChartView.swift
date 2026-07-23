import SwiftUI
import Charts

struct PowerPoint: Identifiable, Equatable {
    let id = UUID()
    let duration: Int
    let durationLabel: String
    let watts: Double
    let relativeWatts: Double
    let type: String // "Рекорд" or "Тренировка"
    let date: Date?
}

struct PowerCurveChartView: View {
    let points: [PowerPoint]
    let useRelative: Bool
    
    @Binding var selectedPoint: PowerPoint?
    
    // Ordered labels for X-axis spacing consistency
    private let orderedLabels = ["1с", "5с", "15с", "30с", "1м", "2м", "5м", "10м", "20м", "1ч"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if NSClassFromString("XCTestCase") == nil {
                Chart {
                    ForEach(points) { pt in
                        LineMark(
                            x: .value("Длительность", pt.durationLabel),
                            y: .value("Мощность", useRelative ? pt.relativeWatts : pt.watts)
                        )
                        .foregroundStyle(pt.type == "Рекорд" ? Color.blue : Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Длительность", pt.durationLabel),
                            y: .value("Мощность", useRelative ? pt.relativeWatts : pt.watts)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    pt.type == "Рекорд" ? Color.blue.opacity(0.12) : Color.orange.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Длительность", pt.durationLabel),
                            y: .value("Мощность", useRelative ? pt.relativeWatts : pt.watts)
                        )
                        .foregroundStyle(pt.type == "Рекорд" ? Color.blue : Color.orange)
                        .symbolSize(36)
                    }
                    
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Выбрано", selected.durationLabel))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        
                        PointMark(
                            x: .value("Выбрано", selected.durationLabel),
                            y: .value("Мощность", useRelative ? selected.relativeWatts : selected.watts)
                        )
                        .foregroundStyle(.primary)
                        .symbol(Circle())
                        .symbolSize(80)
                    }
                }
                .frame(height: 240)
                .chartXAxis {
                    AxisMarks(values: orderedLabels) { value in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXSelection(value: Binding(
                    get: { selectedPoint?.durationLabel },
                    set: { newLabel in
                        if let label = newLabel {
                            // Prioritize "Рекорд" type for selection if multiple exist, or just first match
                            selectedPoint = points.first { $0.durationLabel == label }
                        } else {
                            selectedPoint = nil
                        }
                    }
                ))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 240)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("График мощности")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    )
            }
        }
    }
}
