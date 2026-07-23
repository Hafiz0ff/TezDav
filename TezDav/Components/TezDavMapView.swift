import CoreLocation
import MapKit
import SwiftUI

/// Shared MapKit surface used by route, activity, segment, and heatmap screens.
/// The historical type name is retained to avoid churn at every call site.
struct TezDavMapView: UIViewRepresentable {
    var coordinates: [CLLocationCoordinate2D] = []
    var segments: [MapSegment] = []
    var waypoints: [CLLocationCoordinate2D] = []
    var sportType: String?
    var showStartEndMarkers = false

    var onTap: ((CLLocationCoordinate2D) -> Void)?
    var onWaypointTap: ((Int) -> Void)?

    var heatmapTracks: [HeatmapTrack] = []
    var filterSport = "All"
    var periodDays: Int?
    var opacity = 0.6
    var lineWidth = 3.5
    var colorScheme: PersonalHeatmapView.HeatmapColorScheme?
    var mapStyle: PersonalHeatmapView.MapStyleSelection = .standard
    var onZoneSelected: ((CLLocationCoordinate2D, String, Int, Double, Double) -> Void)?

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

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .includingAll

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        tapGesture.delegate = context.coordinator
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        context.coordinator.mapView = mapView
        context.coordinator.requestLocationIfNeeded()
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.mapType = nativeMapType

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        context.coordinator.overlayStyles.removeAll()

        addRouteOverlay(to: mapView, context: context)
        addSegmentOverlays(to: mapView, context: context)
        addHeatmapOverlays(to: mapView, context: context)
        addWaypointAnnotations(to: mapView)
        addStartEndAnnotations(to: mapView)

        context.coordinator.updateViewportIfNeeded(
            contentCoordinates: allContentCoordinates,
            requestedCenter: cameraCenter,
            requestedZoom: cameraZoom
        )
    }

    private var nativeMapType: MKMapType {
        switch mapStyle {
        case .standard:
            return .standard
        case .imagery:
            return .satellite
        case .hybrid:
            return .hybrid
        }
    }

    private var allContentCoordinates: [CLLocationCoordinate2D] {
        coordinates
            + segments.flatMap(\.coordinates)
            + waypoints
            + heatmapTracks.flatMap(\.coordinates)
    }

    private func addRouteOverlay(to mapView: MKMapView, context: Context) {
        guard coordinates.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        let color: UIColor
        if sportType == "Run" {
            color = .systemGreen
        } else if sportType == "Ride" {
            color = .systemOrange
        } else {
            color = .systemBlue
        }
        context.coordinator.add(polyline, color: color, width: lineWidth, opacity: 1, to: mapView)
    }

    private func addSegmentOverlays(to mapView: MKMapView, context: Context) {
        for segment in segments where segment.coordinates.count > 1 {
            let polyline = MKPolyline(
                coordinates: segment.coordinates,
                count: segment.coordinates.count
            )
            context.coordinator.add(
                polyline,
                color: UIColor(segment.color),
                width: lineWidth,
                opacity: 1,
                to: mapView
            )
        }
    }

    private func addHeatmapOverlays(to mapView: MKMapView, context: Context) {
        for track in heatmapTracks where track.coordinates.count > 1 {
            let polyline = MKPolyline(
                coordinates: track.coordinates,
                count: track.coordinates.count
            )
            context.coordinator.add(
                polyline,
                color: heatmapColor(for: track),
                width: lineWidth,
                opacity: opacity,
                to: mapView
            )
        }
    }

    private func addWaypointAnnotations(to mapView: MKMapView) {
        let annotations = waypoints.enumerated().map { index, coordinate in
            MapPointAnnotation(
                coordinate: coordinate,
                title: "Точка \(index + 1)",
                kind: .waypoint(index: index, isFirst: index == 0, isLast: index == waypoints.count - 1)
            )
        }
        mapView.addAnnotations(annotations)
    }

    private func addStartEndAnnotations(to mapView: MKMapView) {
        guard showStartEndMarkers else { return }
        let routeCoordinates = coordinates.isEmpty ? segments.flatMap(\.coordinates) : coordinates
        guard let start = routeCoordinates.first else { return }

        mapView.addAnnotation(
            MapPointAnnotation(coordinate: start, title: "Старт", kind: .start)
        )
        if let finish = routeCoordinates.last, routeCoordinates.count > 1 {
            mapView.addAnnotation(
                MapPointAnnotation(coordinate: finish, title: "Финиш", kind: .finish)
            )
        }
    }

    private func heatmapColor(for track: HeatmapTrack) -> UIColor {
        switch colorScheme {
        case .orange:
            return .systemOrange
        case .green:
            return .systemGreen
        case .blue:
            return .systemBlue
        case .multisport:
            switch track.sportType {
            case "Run":
                return .systemGreen
            case "Ride":
                return .systemOrange
            default:
                return .systemPurple
            }
        case nil:
            return .systemOrange
        }
    }
}

private final class MapPointAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case waypoint(index: Int, isFirst: Bool, isLast: Bool)
        case start
        case finish
    }

    dynamic var coordinate: CLLocationCoordinate2D
    let title: String?
    let kind: Kind

    init(coordinate: CLLocationCoordinate2D, title: String, kind: Kind) {
        self.coordinate = coordinate
        self.title = title
        self.kind = kind
    }
}

extension TezDavMapView {
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        struct OverlayStyle {
            let color: UIColor
            let width: CGFloat
            let opacity: CGFloat
        }

        var parent: TezDavMapView
        weak var mapView: MKMapView?
        var overlayStyles: [ObjectIdentifier: OverlayStyle] = [:]

        private let locationManager = CLLocationManager()
        private var hasCenteredMap = false
        private var renderedContentCount = 0
        private var lastRequestedCenter: CLLocationCoordinate2D?

        init(parent: TezDavMapView) {
            self.parent = parent
        }

        func requestLocationIfNeeded() {
            guard CLLocationManager.locationServicesEnabled() else { return }
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
        }

        func add(
            _ overlay: MKPolyline,
            color: UIColor,
            width: Double,
            opacity: Double,
            to mapView: MKMapView
        ) {
            overlayStyles[ObjectIdentifier(overlay)] = OverlayStyle(
                color: color,
                width: CGFloat(width),
                opacity: CGFloat(opacity)
            )
            mapView.addOverlay(overlay)
        }

        func updateViewportIfNeeded(
            contentCoordinates: [CLLocationCoordinate2D],
            requestedCenter: CLLocationCoordinate2D?,
            requestedZoom: Float?
        ) {
            guard let mapView else { return }

            if let requestedCenter,
               lastRequestedCenter.map({ !$0.isApproximatelyEqual(to: requestedCenter) }) ?? true {
                lastRequestedCenter = requestedCenter
                hasCenteredMap = true
                mapView.setRegion(
                    region(center: requestedCenter, zoom: requestedZoom ?? 13),
                    animated: false
                )
                return
            }

            guard contentCoordinates.count != renderedContentCount else { return }
            renderedContentCount = contentCoordinates.count
            guard !contentCoordinates.isEmpty else { return }

            hasCenteredMap = true
            if contentCoordinates.count == 1, let coordinate = contentCoordinates.first {
                mapView.setRegion(region(center: coordinate, zoom: 14), animated: true)
            } else {
                let rect = contentCoordinates.reduce(MKMapRect.null) { result, coordinate in
                    let point = MKMapPoint(coordinate)
                    return result.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
                }
                mapView.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 150, left: 52, bottom: 220, right: 52),
                    animated: true
                )
            }
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            if let onTap = parent.onTap {
                onTap(coordinate)
            } else if parent.onZoneSelected != nil {
                Task {
                    await resolveZoneStats(at: coordinate)
                }
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var touchedView: UIView? = touch.view
            while let view = touchedView {
                if view is MKAnnotationView {
                    return false
                }
                touchedView = view.superview
            }
            return true
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard
                !hasCenteredMap,
                parent.allContentCoordinates.isEmpty,
                let location = userLocation.location,
                location.horizontalAccuracy >= 0
            else { return }

            hasCenteredMap = true
            mapView.setRegion(region(center: location.coordinate, zoom: 13), animated: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.region.center
            lastRequestedCenter = center
            parent.cameraCenter = center
            parent.cameraZoom = zoom(for: mapView.region)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard
                let polyline = overlay as? MKPolyline,
                let style = overlayStyles[ObjectIdentifier(polyline)]
            else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = style.color.withAlphaComponent(style.opacity)
            renderer.lineWidth = style.width
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? MapPointAnnotation else { return nil }
            let identifier = "TezDavMapPoint"
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                annotation: point,
                reuseIdentifier: identifier
            )
            view.annotation = point
            view.canShowCallout = false
            view.displayPriority = .required

            switch point.kind {
            case let .waypoint(index, isFirst, isLast):
                view.markerTintColor = isFirst ? .systemGreen : (isLast ? .systemRed : .black)
                view.glyphText = "\(index + 1)"
                view.glyphImage = nil
            case .start:
                view.markerTintColor = .systemGreen
                view.glyphText = nil
                view.glyphImage = UIImage(systemName: "play.fill")
            case .finish:
                view.markerTintColor = .systemRed
                view.glyphText = nil
                view.glyphImage = UIImage(systemName: "flag.fill")
            }
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard
                let point = annotation as? MapPointAnnotation,
                case let .waypoint(index, _, _) = point.kind
            else { return }

            parent.onWaypointTap?(index)
            mapView.deselectAnnotation(annotation, animated: false)
        }

        private func region(center: CLLocationCoordinate2D, zoom: Float) -> MKCoordinateRegion {
            let longitudeDelta = max(0.0005, 360 / pow(2, Double(zoom)))
            return MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: longitudeDelta * 0.7,
                    longitudeDelta: longitudeDelta
                )
            )
        }

        private func zoom(for region: MKCoordinateRegion) -> Float {
            Float(log2(360 / max(region.span.longitudeDelta, 0.000_001)))
        }

        private func resolveZoneStats(at coordinate: CLLocationCoordinate2D) async {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            let zoneName = placemarks?.first.flatMap {
                $0.subLocality ?? $0.locality ?? $0.name
            } ?? "Неизвестный район"

            var count = 0
            var totalDistance = 0.0
            var maximumDistance = 0.0

            for track in parent.heatmapTracks {
                if parent.filterSport != "All", track.sportType != parent.filterSport {
                    continue
                }
                let matched = track.coordinates.contains { coordinate in
                    CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    ).distance(from: location) <= 1_000
                }
                if matched {
                    count += 1
                    totalDistance += track.distanceMeters
                    maximumDistance = max(maximumDistance, track.distanceMeters)
                }
            }

            await MainActor.run {
                parent.onZoneSelected?(
                    coordinate,
                    zoneName,
                    count,
                    totalDistance,
                    maximumDistance
                )
            }
        }
    }
}

private extension CLLocationCoordinate2D {
    func isApproximatelyEqual(to other: CLLocationCoordinate2D) -> Bool {
        abs(latitude - other.latitude) < 0.000_01
            && abs(longitude - other.longitude) < 0.000_01
    }
}
