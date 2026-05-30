import Foundation
import SwiftData
import CoreLocation

struct RouteMatcher {
    
    // Calculates distance using Haversine formula
    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371000.0 // meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
    
    // Compute directed Hausdorff distance from set X to set Y
    static func directedHausdorffDistance(from X: [CLLocationCoordinate2D], to Y: [CLLocationCoordinate2D]) -> Double {
        var maxMinDist = 0.0
        for x in X {
            var minDist = Double.infinity
            for y in Y {
                let dist = haversineDistance(lat1: x.latitude, lon1: x.longitude, lat2: y.latitude, lon2: y.longitude)
                if dist < minDist {
                    minDist = dist
                }
            }
            if minDist > maxMinDist {
                maxMinDist = minDist
            }
        }
        return maxMinDist
    }
    
    // Bidirectional Hausdorff distance
    static func hausdorffDistance(_ X: [CLLocationCoordinate2D], _ Y: [CLLocationCoordinate2D]) -> Double {
        let d1 = directedHausdorffDistance(from: X, to: Y)
        let d2 = directedHausdorffDistance(from: Y, to: X)
        return max(d1, d2)
    }
    
    /// Matches an activity against all saved routes and marks it as planned if it matches.
    static func matchRoute(for activity: Activity, samples: [ActivityStreamSample], context: ModelContext) {
        guard !samples.isEmpty else { return }
        
        let routesDescriptor = FetchDescriptor<SavedRoute>()
        guard let routes = try? context.fetch(routesDescriptor), !routes.isEmpty else { return }
        
        let isCycling = activity.sportType.lowercased().contains("ride")
        let isRunning = activity.sportType.lowercased().contains("run")
        
        // Map samples coordinates
        let sampleCoords = samples.compactMap { sample -> CLLocationCoordinate2D? in
            guard let lat = sample.latitude, let lon = sample.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        guard sampleCoords.count >= 10 else { return }
        
        for route in routes {
            let routeIsRun = route.sportType.lowercased().contains("run")
            let routeIsRide = route.sportType.lowercased().contains("ride")
            
            if (routeIsRun && !isRunning) || (routeIsRide && !isCycling) {
                continue
            }
            
            let routeCoords = route.routeCoordinates
            guard routeCoords.count >= 2 else { continue }
            
            // Hausdorff check for route match. To make it performant on large routes, we can downsample coordinates
            let downsampledRoute = downsample(routeCoords, target: 50)
            let downsampledSamples = downsample(sampleCoords, target: 50)
            
            let hDist = hausdorffDistance(downsampledRoute, downsampledSamples)
            
            if hDist <= 35.0 {
                // Matched! Link activity as planned
                activity.isPlanned = true
                activity.plannedRouteId = route.id
                break
            }
        }
        
        try? context.save()
    }
    
    // Simple path downsampling to target count
    private static func downsample(_ coords: [CLLocationCoordinate2D], target: Int) -> [CLLocationCoordinate2D] {
        guard coords.count > target else { return coords }
        let strideSize = coords.count / target
        var result: [CLLocationCoordinate2D] = []
        for i in stride(from: 0, to: coords.count, by: strideSize) {
            result.append(coords[i])
        }
        if result.count < target, let last = coords.last {
            result.append(last)
        }
        return result
    }
}
