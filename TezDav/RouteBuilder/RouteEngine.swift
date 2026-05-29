import Foundation
import MapKit
import Combine

@MainActor
final class RouteEngine: ObservableObject {
    @Published var waypoints: [CLLocationCoordinate2D] = []
    @Published var routeSegments: [[CLLocationCoordinate2D]] = []
    @Published var segmentDistances: [Double] = []
    
    @Published var fullRouteCoordinates: [CLLocationCoordinate2D] = []
    @Published var totalDistance: Double = 0          // meters
    @Published var totalElevationGain: Double = 0     // meters
    @Published var totalElevationLoss: Double = 0     // meters
    @Published var elevationProfile: [ElevationPoint] = []
    @Published var isCalculating = false
    
    var sportType: String = "Run" {
        didSet {
            Task {
                await rebuildSegments()
            }
        }
    }
    
    func addWaypoint(_ coordinate: CLLocationCoordinate2D) async {
        isCalculating = true
        defer { isCalculating = false }
        
        if waypoints.isEmpty {
            waypoints.append(coordinate)
            fullRouteCoordinates = [coordinate]
            totalDistance = 0
            elevationProfile = [ElevationPoint(distance: 0, elevation: 150.0)]
            totalElevationGain = 0
            totalElevationLoss = 0
        } else {
            let from = waypoints.last!
            waypoints.append(coordinate)
            
            let (coords, dist) = await calculateSegment(from: from, to: coordinate)
            routeSegments.append(coords)
            segmentDistances.append(dist)
            
            updateFullRoute()
            await updateElevationProfile()
        }
    }
    
    func removeWaypoint(at index: Int) async {
        guard index >= 0 && index < waypoints.count else { return }
        isCalculating = true
        defer { isCalculating = false }
        
        waypoints.remove(at: index)
        await rebuildSegments()
    }
    
    func moveWaypoint(at index: Int, to coordinate: CLLocationCoordinate2D) async {
        guard index >= 0 && index < waypoints.count else { return }
        isCalculating = true
        defer { isCalculating = false }
        
        waypoints[index] = coordinate
        await rebuildSegments()
    }
    
    func undo() {
        guard !waypoints.isEmpty else { return }
        if waypoints.count == 1 {
            clearAll()
        } else {
            waypoints.removeLast()
            if !routeSegments.isEmpty {
                routeSegments.removeLast()
            }
            if !segmentDistances.isEmpty {
                segmentDistances.removeLast()
            }
            updateFullRoute()
            Task {
                isCalculating = true
                await updateElevationProfile()
                isCalculating = false
            }
        }
    }
    
    func clearAll() {
        waypoints = []
        routeSegments = []
        segmentDistances = []
        fullRouteCoordinates = []
        totalDistance = 0
        totalElevationGain = 0
        totalElevationLoss = 0
        elevationProfile = []
    }
    
    func loadFromRoute(_ route: SavedRoute) {
        self.waypoints = route.waypoints
        self.sportType = route.sportType
        self.totalDistance = route.totalDistanceMeters
        self.totalElevationGain = route.totalElevationGain
        self.totalElevationLoss = route.totalElevationLoss
        self.elevationProfile = route.elevationProfile
        
        let coords = route.routeCoordinates
        if !coords.isEmpty {
            self.fullRouteCoordinates = coords
            self.routeSegments = [coords]
            self.segmentDistances = [route.totalDistanceMeters]
        }
    }
    
    func estimatedTime(averagePaceSecPerKm: Double) -> TimeInterval {
        let distanceKm = totalDistance / 1000.0
        return distanceKm * averagePaceSecPerKm
    }
    
    private func updateFullRoute() {
        var coords: [CLLocationCoordinate2D] = []
        for (idx, seg) in routeSegments.enumerated() {
            if idx == 0 {
                coords.append(contentsOf: seg)
            } else {
                coords.append(contentsOf: seg.dropFirst())
            }
        }
        if coords.isEmpty && !waypoints.isEmpty {
            coords = waypoints
        }
        fullRouteCoordinates = coords
        totalDistance = segmentDistances.reduce(0, +)
    }
    
    private func rebuildSegments() async {
        routeSegments = []
        segmentDistances = []
        
        if waypoints.isEmpty {
            fullRouteCoordinates = []
            totalDistance = 0
            elevationProfile = []
            totalElevationGain = 0
            totalElevationLoss = 0
            return
        }
        
        if waypoints.count == 1 {
            fullRouteCoordinates = waypoints
            totalDistance = 0
            elevationProfile = [ElevationPoint(distance: 0, elevation: 150.0)]
            totalElevationGain = 0
            totalElevationLoss = 0
            return
        }
        
        for i in 1..<waypoints.count {
            let (coords, dist) = await calculateSegment(from: waypoints[i-1], to: waypoints[i])
            routeSegments.append(coords)
            segmentDistances.append(dist)
        }
        
        updateFullRoute()
        await updateElevationProfile()
    }
    
    private func calculateSegment(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> ([CLLocationCoordinate2D], Double) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = sportType == "Run" ? .walking : .automobile
        
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                let pointCount = route.polyline.pointCount
                var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                // Filter out any invalid coordinates just in case
                let validCoords = coords.filter { CLLocationCoordinate2DIsValid($0) }
                return (validCoords.isEmpty ? [from, to] : validCoords, route.distance)
            }
        } catch {
            print("MKDirections failed: \(error.localizedDescription). Falling back to straight line.")
        }
        
        // Fallback: straight line
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let dist = loc1.distance(from: loc2)
        return ([from, to], dist)
    }
    
    private func updateElevationProfile() async {
        guard !fullRouteCoordinates.isEmpty else {
            self.elevationProfile = []
            self.totalElevationGain = 0
            self.totalElevationLoss = 0
            return
        }
        
        let profile = await ElevationService.fetchElevationProfile(for: fullRouteCoordinates)
        self.elevationProfile = profile
        
        var gain = 0.0
        var loss = 0.0
        for i in 1..<profile.count {
            let diff = profile[i].elevation - profile[i-1].elevation
            if diff > 0 {
                gain += diff
            } else {
                loss += abs(diff)
            }
        }
        self.totalElevationGain = gain
        self.totalElevationLoss = loss
    }
}
