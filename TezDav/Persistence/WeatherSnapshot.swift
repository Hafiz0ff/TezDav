import Foundation
import SwiftData

@Model
final class WeatherSnapshot {
    @Attribute(.unique) var id: UUID
    var temperature: Double // in °C
    var humidity: Double    // in %
    var windSpeed: Double   // in m/s
    var condition: String   // e.g., "Clear", "Cloudy", "Rain", "Snow"
    var latitude: Double
    var longitude: Double
    var date: Date
    
    @Relationship(deleteRule: .nullify)
    var activity: Activity?
    
    init(
        id: UUID = UUID(),
        temperature: Double,
        humidity: Double,
        windSpeed: Double,
        condition: String,
        latitude: Double,
        longitude: Double,
        date: Date
    ) {
        self.id = id
        self.temperature = temperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.condition = condition
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
    }
}
