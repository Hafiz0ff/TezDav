import XCTest
import CoreLocation
@testable import TezDav

final class PolylineEncoderTests: XCTestCase {
    
    func testDecodeKnownPolyline() {
        // Standard polyline for a small path: (38.56, 68.79) -> (38.57, 68.80)
        let polyline = "_gjjFopzbLo}@o}@"
        let coordinates = PolylineEncoder.decode(polyline: polyline)
        
        XCTAssertEqual(coordinates.count, 2)
        XCTAssertEqual(coordinates[0].latitude, 38.56, accuracy: 1e-5)
        XCTAssertEqual(coordinates[0].longitude, 68.79, accuracy: 1e-5)
        XCTAssertEqual(coordinates[1].latitude, 38.57, accuracy: 1e-5)
        XCTAssertEqual(coordinates[1].longitude, 68.80, accuracy: 1e-5)
    }
    
    func testEncodeDecodeRoundtrip() {
        let originalCoordinates = [
            CLLocationCoordinate2D(latitude: 38.56123, longitude: 68.79456),
            CLLocationCoordinate2D(latitude: 38.56543, longitude: 68.79123),
            CLLocationCoordinate2D(latitude: 38.57234, longitude: 68.80567)
        ]
        
        let encoded = PolylineEncoder.encode(coordinates: originalCoordinates)
        let decoded = PolylineEncoder.decode(polyline: encoded)
        
        XCTAssertEqual(decoded.count, originalCoordinates.count)
        
        for i in 0..<originalCoordinates.count {
            XCTAssertEqual(decoded[i].latitude, originalCoordinates[i].latitude, accuracy: 1e-5)
            XCTAssertEqual(decoded[i].longitude, originalCoordinates[i].longitude, accuracy: 1e-5)
        }
    }
    
    func testEncodeEmptyArray() {
        let coordinates: [CLLocationCoordinate2D] = []
        let encoded = PolylineEncoder.encode(coordinates: coordinates)
        XCTAssertEqual(encoded, "")
        
        let decoded = PolylineEncoder.decode(polyline: "")
        XCTAssertTrue(decoded.isEmpty)
    }
}
