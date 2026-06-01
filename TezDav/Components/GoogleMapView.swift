// swiftlint:disable cyclomatic_complexity function_body_length
import SwiftUI
import GoogleMaps
import CoreLocation

struct GoogleMapView: UIViewRepresentable {
    var coordinates: [CLLocationCoordinate2D] = []
    var segments: [MapSegment] = []
    var waypoints: [CLLocationCoordinate2D] = []
    var sportType: String? = nil
    var showStartEndMarkers: Bool = false
    
    // Callbacks
    var onTap: ((CLLocationCoordinate2D) -> Void)? = nil
    var onWaypointTap: ((Int) -> Void)? = nil
    
    // Heatmap mode
    var heatmapTracks: [HeatmapTrack] = []
    var filterSport: String = "All"
    var periodDays: Int? = nil
    var opacity: Double = 0.6
    var lineWidth: Double = 3.5
    var colorScheme: PersonalHeatmapView.HeatmapColorScheme? = nil
    var mapStyle: PersonalHeatmapView.MapStyleSelection = .standard
    var onZoneSelected: ((CLLocationCoordinate2D, String, Int, Double, Double) -> Void)? = nil
    
    // Binding camera position center to preserve zoom states across view updates
    @Binding var cameraCenter: CLLocationCoordinate2D?
    @Binding var cameraZoom: Float?

    init(
        coordinates: [CLLocationCoordinate2D] = [],
        segments: [MapSegment] = [],
        waypoints: [CLLocationCoordinate2D] = [],
        sportType: String? = nil,
        showStartEndMarkers: Bool = false,
        onTap: ((CLLocationCoordinate2D) -> Void)? = nil,
        onWaypointTap: ((Int) -> Void)? = nil,
        heatmapTracks: [HeatmapTrack] = [],
        filterSport: String = "All",
        periodDays: Int? = nil,
        opacity: Double = 0.6,
        lineWidth: Double = 3.5,
        colorScheme: PersonalHeatmapView.HeatmapColorScheme? = nil,
        mapStyle: PersonalHeatmapView.MapStyleSelection = .standard,
        onZoneSelected: ((CLLocationCoordinate2D, String, Int, Double, Double) -> Void)? = nil,
        cameraCenter: Binding<CLLocationCoordinate2D?> = .constant(nil),
        cameraZoom: Binding<Float?> = .constant(nil)
    ) {
        self.coordinates = coordinates
        self.segments = segments
        self.waypoints = waypoints
        self.sportType = sportType
        self.showStartEndMarkers = showStartEndMarkers
        self.onTap = onTap
        self.onWaypointTap = onWaypointTap
        self.heatmapTracks = heatmapTracks
        self.filterSport = filterSport
        self.periodDays = periodDays
        self.opacity = opacity
        self.lineWidth = lineWidth
        self.colorScheme = colorScheme
        self.mapStyle = mapStyle
        self.onZoneSelected = onZoneSelected
        self._cameraCenter = cameraCenter
        self._cameraZoom = cameraZoom
    }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        
        let initialCamera: GMSCameraPosition
        if let center = cameraCenter, let zoom = cameraZoom {
            initialCamera = GMSCameraPosition.camera(withTarget: center, zoom: zoom)
        } else if let first = coordinates.first {
            initialCamera = GMSCameraPosition.camera(withTarget: first, zoom: 14)
        } else if let firstWaypoint = waypoints.first {
            initialCamera = GMSCameraPosition.camera(withTarget: firstWaypoint, zoom: 14)
        } else if let firstTrack = heatmapTracks.first, let firstCoord = firstTrack.coordinates.first {
            initialCamera = GMSCameraPosition.camera(withTarget: firstCoord, zoom: 12)
        } else {
            // Default center is Dushanbe, Tajikistan
            initialCamera = GMSCameraPosition.camera(withLatitude: 38.5598, longitude: 68.7870, zoom: 12)
        }
        options.camera = initialCamera
        
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        
        applyMapStyle(to: mapView)
        
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Prevent infinite loops by temporarily disabling delegate callbacks
        mapView.delegate = nil
        
        mapView.clear()
        
        // Update map type
        switch mapStyle {
        case .standard: mapView.mapType = .normal
        case .imagery: mapView.mapType = .satellite
        case .hybrid: mapView.mapType = .hybrid
        }
        
        applyMapStyle(to: mapView)
        
        // Draw flat coordinates route polyline
        if !coordinates.isEmpty {
            let path = GMSMutablePath()
            for coord in coordinates {
                path.add(coord)
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = CGFloat(lineWidth)
            
            if let sport = sportType {
                polyline.strokeColor = sport == "Run" ? .systemGreen : .systemOrange
            } else {
                polyline.strokeColor = .systemBlue
            }
            polyline.map = mapView
        }
        
        // Draw segmented colored route lines (for ActivityDetailView)
        for segment in segments {
            let path = GMSMutablePath()
            for coord in segment.coordinates {
                path.add(coord)
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = CGFloat(lineWidth)
            polyline.strokeColor = UIColor(segment.color)
            polyline.map = mapView
        }
        
        // Draw heatmap tracks
        for track in heatmapTracks {
            let path = GMSMutablePath()
            for coord in track.coordinates {
                path.add(coord)
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = CGFloat(lineWidth)
            
            let color = getHeatmapTrackColor(for: track)
            polyline.strokeColor = color.withAlphaComponent(CGFloat(opacity))
            polyline.map = mapView
        }
        
        // Draw waypoint markers (for RouteBuilderView)
        for (index, waypoint) in waypoints.enumerated() {
            let marker = GMSMarker(position: waypoint)
            marker.userData = index
            marker.title = "Точка \(index + 1)"
            
            let circleColor: UIColor
            if index == 0 {
                circleColor = .systemGreen
            } else if index == waypoints.count - 1 {
                circleColor = .systemRed
            } else {
                circleColor = .black
            }
            
            marker.iconView = createMarkerIconView(label: "\(index + 1)", color: circleColor)
            marker.map = mapView
        }
        
        // Draw start / end markers (for RouteDetailView & SegmentDetailView)
        if showStartEndMarkers {
            let allCoords = coordinates.isEmpty ? segments.flatMap { $0.coordinates } : coordinates
            
            if let start = allCoords.first {
                let startMarker = GMSMarker(position: start)
                startMarker.title = "Старт"
                startMarker.iconView = createIconBadgeView(systemImage: "play.circle.fill", color: .systemGreen)
                startMarker.map = mapView
            }
            
            if let end = allCoords.last, allCoords.count > 1 {
                let endMarker = GMSMarker(position: end)
                endMarker.title = "Финиш"
                endMarker.iconView = createIconBadgeView(systemImage: "flag.circle.fill", color: .systemRed)
                endMarker.map = mapView
            }
        }
        
        // Re-enable delegate callbacks
        mapView.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if let onTap = parent.onTap {
                onTap(coordinate)
            } else if parent.onZoneSelected != nil {
                Task {
                    await resolveZoneStats(at: coordinate)
                }
            }
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let index = marker.userData as? Int {
                parent.onWaypointTap?(index)
                return true
            }
            return false
        }
        
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            parent.cameraCenter = position.target
            parent.cameraZoom = position.zoom
        }
        
        private func resolveZoneStats(at coordinate: CLLocationCoordinate2D) async {
            let geocoder = CLGeocoder()
            let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            var zoneName = "Неизвестный район"
            
            if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
               let first = placemarks.first {
                zoneName = first.subLocality ?? first.locality ?? first.name ?? "Район"
            }
            
            var count = 0
            var totalDist = 0.0
            var maxDist = 0.0
            
            let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            for track in parent.heatmapTracks {
                if parent.filterSport != "All" && track.sportType != parent.filterSport { continue }
                
                var matched = false
                for trackCoord in track.coordinates {
                    let loc = CLLocation(latitude: trackCoord.latitude, longitude: trackCoord.longitude)
                    if loc.distance(from: searchLocation) <= 1000.0 {
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
            
            await MainActor.run {
                parent.onZoneSelected?(coordinate, zoneName, count, totalDist, maxDist)
            }
        }
    }
    
    // MARK: - View Helper Generators
    
    private func applyMapStyle(to mapView: GMSMapView) {
        if mapView.mapType == .normal {
            let darkMapStyleJSON = """
            [
              {
                "elementType": "geometry",
                "stylers": [
                  { "color": "#1c2128" }
                ]
              },
              {
                "elementType": "labels.text.fill",
                "stylers": [
                  { "color": "#768390" }
                ]
              },
              {
                "elementType": "labels.text.stroke",
                "stylers": [
                  { "color": "#1c2128" }
                ]
              },
              {
                "featureType": "administrative.locality",
                "elementType": "labels.text.fill",
                "stylers": [
                  { "color": "#ecad80" }
                ]
              },
              {
                "featureType": "poi",
                "elementType": "labels.text.fill",
                "stylers": [
                  { "color": "#ecad80" }
                ]
              },
              {
                "featureType": "poi.park",
                "elementType": "geometry",
                "stylers": [
                  { "color": "#222c2b" }
                ]
              },
              {
                "featureType": "poi.park",
                "elementType": "labels.text.fill",
                "stylers": [
                  { "color": "#60936b" }
                ]
              },
              {
                "featureType": "road",
                "elementType": "geometry",
                "stylers": [
                  { "color": "#2d333b" }
                ]
              },
              {
                "featureType": "road",
                "elementType": "geometry.stroke",
                "stylers": [
                  { "color": "#1c2128" }
                ]
              },
              {
                "featureType": "road",
                "elementType": "labels.text.fill",
                "stylers": [
                  { "color": "#768390" }
                ]
              },
              {
                "featureType": "road.highway",
                "elementType": "geometry",
                "stylers": [
                  { "color": "#424b54" }
                ]
              },
              {
                "featureType": "road.highway",
                "elementType": "geometry.stroke",
                "stylers": [
                  { "color": "#1c2128" }
                ]
              },
              {
                "featureType": "water",
                "elementType": "geometry",
                "stylers": [
                  { "color": "#182635" }
                ]
              },
              {
                "featureType": "water",
                "elementType": "labels.text.fill",
                "stylers": [
                  { "color": "#537f9e" }
                ]
              }
            ]
            """
            mapView.mapStyle = try? GMSMapStyle(jsonString: darkMapStyleJSON)
        }
    }
    
    private func getHeatmapTrackColor(for track: HeatmapTrack) -> UIColor {
        guard let scheme = colorScheme else { return .systemOrange }
        
        switch scheme {
        case .orange:
            return .systemOrange
        case .green:
            return .systemGreen
        case .blue:
            return .systemBlue
        case .multisport:
            if track.sportType == "Run" {
                return .systemGreen
            } else if track.sportType == "Ride" {
                return .systemOrange
            } else {
                return .systemPurple
            }
        }
    }
    
    private func createMarkerIconView(label: String, color: UIColor) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        container.backgroundColor = .clear
        
        let circle = UIView(frame: CGRect(x: 1, y: 1, width: 26, height: 26))
        circle.backgroundColor = color
        circle.layer.cornerRadius = 13
        circle.layer.borderWidth = 2
        circle.layer.borderColor = UIColor.white.cgColor
        circle.layer.shadowColor = UIColor.black.cgColor
        circle.layer.shadowOpacity = 0.3
        circle.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        circle.layer.shadowRadius = 2.0
        
        let labelView = UILabel(frame: circle.bounds)
        labelView.text = label
        labelView.textColor = .white
        labelView.font = .systemFont(ofSize: 11, weight: .bold)
        labelView.textAlignment = .center
        
        circle.addSubview(labelView)
        container.addSubview(circle)
        return container
    }
    
    private func createIconBadgeView(systemImage: String, color: UIColor) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        container.backgroundColor = .clear
        
        let imageView = UIImageView(frame: container.bounds)
        imageView.image = UIImage(systemName: systemImage)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        
        // Add white background circle
        let bgCircle = UIView(frame: CGRect(x: 4, y: 4, width: 24, height: 24))
        bgCircle.backgroundColor = .white
        bgCircle.layer.cornerRadius = 12
        
        container.addSubview(bgCircle)
        container.addSubview(imageView)
        return container
    }
}
