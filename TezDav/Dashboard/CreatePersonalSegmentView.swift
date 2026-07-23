import SwiftUI
import MapKit
import SwiftData

struct CreatePersonalSegmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let activity: Activity
    let samples: [ActivityStreamSample]
    
    @State private var segmentName: String = ""
    @State private var startRatio: Double = 0.1
    @State private var endRatio: Double = 0.9
    
    private var isRussian: Bool {
        AppLanguage.isRussian
    }
    
    private var coordinates: [CLLocationCoordinate2D] {
        samples.compactMap { sample -> CLLocationCoordinate2D? in
            guard let lat = sample.latitude, let lon = sample.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    // Sub-selected coordinate list for the segment
    private var selectedCoordinates: [CLLocationCoordinate2D] {
        let coords = coordinates
        guard coords.count >= 2 else { return [] }
        let startIndex = min(coords.count - 2, max(0, Int(Double(coords.count) * startRatio)))
        let endIndex = min(coords.count - 1, max(startIndex + 1, Int(Double(coords.count) * endRatio)))
        return Array(coords[startIndex...endIndex])
    }
    
    @State private var cameraCenter: CLLocationCoordinate2D? = nil
    @State private var cameraZoom: Float? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Segment Name
                TextField(isRussian ? "Название сегмента" : "Segment Name", text: $segmentName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top)
                
                TezDavMapView(
                    coordinates: selectedCoordinates,
                    segments: [MapSegment(coordinates: coordinates, color: Color.gray.opacity(0.5))],
                    sportType: "Segment",
                    showStartEndMarkers: true,
                    cameraCenter: $cameraCenter,
                    cameraZoom: $cameraZoom
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                // Double Slider simulation via two sliders
                VStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text(String(format: isRussian ? "Начало: %.0f%%" : "Start: %.0f%%", startRatio * 100))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Slider(value: $startRatio, in: 0...0.95)
                            .tint(.green)
                            .onChange(of: startRatio) { _, newValue in
                                if newValue >= endRatio {
                                    endRatio = min(1.0, newValue + 0.05)
                                }
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text(String(format: isRussian ? "Конец: %.0f%%" : "End: %.0f%%", endRatio * 100))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Slider(value: $endRatio, in: 0.05...1.0)
                            .tint(.red)
                            .onChange(of: endRatio) { _, newValue in
                                if newValue <= startRatio {
                                    startRatio = max(0.0, newValue - 0.05)
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                // Calculated details
                VStack(spacing: 4) {
                    Text(isRussian ? "Характеристики сегмента" : "Segment Details")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        VStack {
                            Text(isRussian ? "Дистанция" : "Distance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: isRussian ? "%.2f км" : "%.2f km", calculateSegmentDistance(selectedCoordinates) / 1000.0))
                                .font(.headline)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(isRussian ? "Создать личный сегмент" : "Create Personal Segment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isRussian ? "Отмена" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRussian ? "Создать" : "Create") {
                        saveSegment(distance: calculateSegmentDistance(selectedCoordinates))
                    }
                    .disabled(segmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCoordinates.count < 2)
                }
            }
            .onAppear {
                if segmentName.isEmpty {
                    segmentName = isRussian ? "Мой сегмент" : "My Segment"
                }
            }
        }
    }
    
    private func calculateSegmentDistance(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 2 else { return 0.0 }
        var total = 0.0
        for i in 0..<(coords.count - 1) {
            total += PersonalSegmentMatcher.haversineDistance(
                lat1: coords[i].latitude,
                lon1: coords[i].longitude,
                lat2: coords[i+1].latitude,
                lon2: coords[i+1].longitude
            )
        }
        return total
    }
    
    private func saveSegment(distance: Double) {
        let coords = selectedCoordinates
        guard coords.count >= 2, let start = coords.first, let end = coords.last else { return }
        
        let newSegment = PersonalSegment(
            name: segmentName,
            sportType: activity.sportType,
            distanceMeters: distance,
            startLatitude: start.latitude,
            startLongitude: start.longitude,
            endLatitude: end.latitude,
            endLongitude: end.longitude
        )
        newSegment.coordinates = coords
        
        modelContext.insert(newSegment)
        try? modelContext.save()
        
        // Trigger matching immediately for all activities with streams
        let allActDescriptor = FetchDescriptor<Activity>()
        if let allActivities = try? modelContext.fetch(allActDescriptor) {
            for act in allActivities {
                if act.streamsImported {
                    let actId = act.stravaId
                    let streamDescriptor = FetchDescriptor<ActivityStreamSample>(
                        predicate: #Predicate<ActivityStreamSample> { $0.activityId == actId }
                    )
                    if let actSamples = try? modelContext.fetch(streamDescriptor), !actSamples.isEmpty {
                        PersonalSegmentMatcher.matchPersonalSegments(for: act, samples: actSamples, context: modelContext)
                    }
                }
            }
        }
        
        dismiss()
    }
}
