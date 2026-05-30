import XCTest
import SwiftData
@testable import TezDav

@MainActor
final class WeatherServiceTests: XCTestCase {
    
    func testWeatherMappingCodes() {
        // Since mapping is private, we can test the fallback mock weather generator which uses it and returns high quality conditions
        let date = Date()
        let snapshot1 = WeatherService.shared.generateMockWeather(latitude: 38.56, longitude: 68.79, date: date)
        
        XCTAssertNotNil(snapshot1.condition)
        XCTAssertGreaterThanOrEqual(snapshot1.humidity, 0.0)
        XCTAssertLessThanOrEqual(snapshot1.humidity, 100.0)
        XCTAssertGreaterThanOrEqual(snapshot1.windSpeed, 0.0)
    }
    
    func testWeatherSeasonalSimulations() {
        let calendar = Calendar.current
        var summerComponents = DateComponents()
        summerComponents.year = 2026
        summerComponents.month = 7 // July
        summerComponents.day = 15
        summerComponents.hour = 14
        let summerDate = calendar.date(from: summerComponents)!
        
        let summerSnapshot = WeatherService.shared.generateMockWeather(latitude: 38.56, longitude: 68.79, date: summerDate)
        XCTAssertGreaterThan(summerSnapshot.temperature, 20.0, "Summer afternoon temperature should be warm")
        
        var winterComponents = DateComponents()
        winterComponents.year = 2026
        winterComponents.month = 1 // January
        winterComponents.day = 15
        winterComponents.hour = 23
        let winterDate = calendar.date(from: winterComponents)!
        
        let winterSnapshot = WeatherService.shared.generateMockWeather(latitude: 38.56, longitude: 68.79, date: winterDate)
        XCTAssertLessThan(winterSnapshot.temperature, 10.0, "Winter night temperature should be cold")
    }
}
