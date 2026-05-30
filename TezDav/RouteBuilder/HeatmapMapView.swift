import SwiftUI
import MapKit

struct HeatmapMapView: UIViewRepresentable {
    let tracks: [HeatmapTrack]
    let filterSport: String
    let periodDays: Int?
    let opacity: Double
    let lineWidth: Double
    let colorScheme: PersonalHeatmapView.HeatmapColorScheme
    let mapStyle: PersonalHeatmapView.MapStyleSelection
    
    // Callback when user taps to show zone statistics
    var onZoneSelected: (CLLocationCoordinate2D, String, Int, Double, Double) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Add double-tap accessibility description hint
        mapView.accessibilityHint = "Дважды коснитесь для полноэкранного режима"
        
        // Tap Gesture
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type
        switch mapStyle {
        case .standard: mapView.mapType = .standard
        case .imagery: mapView.mapType = .satellite
        case .hybrid: mapView.mapType = .hybrid
        }
        
        // Update overlays
        let currentOverlays = mapView.overlays
        mapView.removeOverlays(currentOverlays)
        
        let overlay = GlobalHeatmapTileOverlay(
            tracks: tracks,
            filterSport: filterSport,
            periodDays: periodDays,
            colorScheme: colorScheme,
            opacity: opacity,
            lineWidth: lineWidth
        )
        overlay.canReplaceMapContent = false
        mapView.addOverlay(overlay, level: .aboveRoads)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: HeatmapMapView
        
        init(_ parent: HeatmapMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Perform reverse search and geocode to get zone name
            Task {
                await resolveZoneStats(at: coord, in: mapView)
            }
        }
        
        private func resolveZoneStats(at coordinate: CLLocationCoordinate2D, in mapView: MKMapView) async {
            // Natural language search query using MKLocalSearch
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "address"
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 100,
                longitudinalMeters: 100
            )
            
            let search = MKLocalSearch(request: request)
            var zoneName = "Неизвестный район"
            
            if let response = try? await search.start(), let item = response.mapItems.first {
                let placemark = item.placemark
                zoneName = placemark.subLocality ?? placemark.locality ?? placemark.name ?? "Район"
            } else {
                // Geocoder fallback
                let geocoder = CLGeocoder()
                let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
                   let first = placemarks.first {
                    zoneName = first.subLocality ?? first.locality ?? "Район"
                }
            }
            
            // Calculate stats inside a 1km radius zone
            var count = 0
            var totalDist = 0.0
            var maxDist = 0.0
            
            let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            for track in parent.tracks {
                // Filter by sport
                if parent.filterSport != "All" && track.sportType != parent.filterSport { continue }
                
                var matched = false
                for trackCoord in track.coordinates {
                    let loc = CLLocation(latitude: trackCoord.latitude, longitude: trackCoord.longitude)
                    if loc.distance(from: searchLocation) <= 1000.0 { // 1 km radius
                        matched = true
                        break
                    }
                }
                
                if matched {
                    count += 1
                    totalDist += track.distanceMeters
                    maxDist = max(maxDist, track.distanceMeters)
                }
            }
            
            // Callback UI thread
            await MainActor.run {
                parent.onZoneSelected(coordinate, zoneName, count, totalDist, maxDist)
            }
        }
    }
}

struct HeatmapShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
