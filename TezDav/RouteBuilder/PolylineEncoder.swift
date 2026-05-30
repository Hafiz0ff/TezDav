import Foundation
import CoreLocation

/// Utility class to encode and decode lists of CoreLocation coordinates
/// using the standard Google Polyline Algorithm.
struct PolylineEncoder {
    
    /// Decodes an encoded polyline string into an array of CLLocationCoordinate2D.
    /// - Parameter polyline: The Google Polyline encoded string.
    /// - Returns: An array of coordinates.
    static func decode(polyline: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = polyline.startIndex
        
        var lat = 0
        var lng = 0
        
        while index < polyline.endIndex {
            var b: Int
            var shift = 0
            var result = 0
            
            repeat {
                if index >= polyline.endIndex { break }
                b = Int(polyline[index].asciiValue! - 63)
                index = polyline.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            
            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat
            
            shift = 0
            result = 0
            
            repeat {
                if index >= polyline.endIndex { break }
                b = Int(polyline[index].asciiValue! - 63)
                index = polyline.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            
            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng
            
            let latitude = Double(lat) * 1e-5
            let longitude = Double(lng) * 1e-5
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        
        return coordinates
    }
    
    /// Encodes an array of CLLocationCoordinate2D into a Google Polyline string.
    /// - Parameter coordinates: The array of coordinates.
    /// - Returns: An encoded string.
    static func encode(coordinates: [CLLocationCoordinate2D]) -> String {
        var polyline = ""
        var lastLat = 0
        var lastLng = 0
        
        for coord in coordinates {
            let lat = Int(round(coord.latitude * 1e5))
            let lng = Int(round(coord.longitude * 1e5))
            
            let dLat = lat - lastLat
            let dLng = lng - lastLng
            
            lastLat = lat
            lastLng = lng
            
            polyline += encodeValue(dLat)
            polyline += encodeValue(dLng)
        }
        
        return polyline
    }
    
    private static func encodeValue(_ value: Int) -> String {
        var val = value < 0 ? ~(value << 1) : (value << 1)
        var poly = ""
        
        while val >= 0x20 {
            let chunk = (val & 0x1f) | 0x20
            if let scalar = UnicodeScalar(chunk + 63) {
                poly.append(Character(scalar))
            }
            val >>= 5
        }
        
        if let scalar = UnicodeScalar(val + 63) {
            poly.append(Character(scalar))
        }
        
        return poly
    }
}
