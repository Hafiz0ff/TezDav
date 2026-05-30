import SwiftUI
import SwiftData

struct WorkoutSimulatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var segments: [Segment]
    @ObservedObject var simulator = WorkoutSimulator.shared
    
    @State private var sportType = "Run"
    @State private var selectedSegmentId: UUID? = nil
    @State private var speedMultiplier = 1
    
    var filteredSegments: [Segment] {
        segments.filter { segment in
            let isCycling = sportType.lowercased().contains("ride")
            let segmentIsRide = segment.sportType.lowercased().contains("ride")
            let segmentIsRun = segment.sportType.lowercased().contains("run")
            return (isCycling && segmentIsRide) || (!isCycling && segmentIsRun)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if simulator.isSimulating {
                    // Simulation Active Metrics Section
                    Section("Симуляция активна") {
                        HStack {
                            Text("Вид спорта")
                            Spacer()
                            Text(sportType == "Run" ? "🏃‍♂️ Бег" : "🚴‍♂️ Велосипед")
                                .bold()
                        }
                        
                        if let seg = simulator.selectedSegment {
                            HStack {
                                Text("Активный сегмент")
                                Spacer()
                                Text(seg.name)
                                    .foregroundColor(.orange)
                                    .bold()
                            }
                        }
                        
                        HStack {
                            Text("Время")
                            Spacer()
                            Text(formatDuration(simulator.elapsed))
                                .monospacedDigit()
                                .bold()
                        }
                        
                        HStack {
                            Text("Дистанция")
                            Spacer()
                            Text(String(format: "%.1f м", simulator.distance))
                                .monospacedDigit()
                                .bold()
                        }
                        
                        HStack {
                            Text("Текущие координаты")
                            Spacer()
                            Text(String(format: "%.5f, %.5f", simulator.currentLatitude, simulator.currentLongitude))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        
                        Button(role: .destructive) {
                            simulator.stop()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Остановить симуляцию", systemImage: "stop.fill")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                } else {
                    // Simulator Setup Settings
                    Section("Настройки тренировки") {
                        Picker("Вид спорта", selection: $sportType) {
                            Text("Бег").tag("Run")
                            Text("Велосипед").tag("Ride")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: sportType) { _, _ in
                            // Auto select the first matching segment
                            selectedSegmentId = filteredSegments.first?.id
                        }
                        
                        Picker("Сегмент для теста", selection: $selectedSegmentId) {
                            Text("Без сегмента (обычная)").tag(UUID?.none)
                            ForEach(filteredSegments) { seg in
                                Text("\(seg.name) (\(Int(seg.distanceMeters)) м)").tag(UUID?.some(seg.id))
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Ускорение симуляции", selection: $speedMultiplier) {
                            Text("1x (Реалтайм)").tag(1)
                            Text("2x").tag(2)
                            Text("5x").tag(5)
                            Text("10x (Супербыстро)").tag(10)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Section {
                        Button {
                            let chosenSegment = segments.first(where: { $0.id == selectedSegmentId })
                            
                            // Seed default segments if empty
                            if segments.isEmpty {
                                SegmentMatcher.seedSegments(context: modelContext)
                            }
                            
                            simulator.start(
                                sportType: sportType,
                                segment: chosenSegment,
                                speedMultiplier: speedMultiplier,
                                context: modelContext
                            )
                        } label: {
                            HStack {
                                Spacer()
                                Label("Начать симуляцию", systemImage: "play.fill")
                                    .bold()
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.blue)
                    } footer: {
                        Text("Симуляция генерирует GPS-координаты по треку сегмента с шагом в 3 секунды, позволяя проверить вхождение в сегмент и отображение Dynamic Island / Live Activity.")
                    }
                }
            }
            .navigationTitle("Workout Simulator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedSegmentId == nil {
                    selectedSegmentId = filteredSegments.first?.id
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
