import Foundation

struct StravaActivitySummary: Decodable, Sendable {
    let id: Int64
    let name: String
    let sportType: String
    let startDate: Date
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Double
    let averageHeartrate: Double?
    let averageWatts: Double?
    let averageCadence: Double?
    let averageSpeed: Double?
    let map: StravaMap?
    let startLatlng: [Double]?
    let gearId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sportType = "sport_type"
        case startDate = "start_date"
        case distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageHeartrate = "average_heartrate"
        case averageWatts = "average_watts"
        case averageCadence = "average_cadence"
        case averageSpeed = "average_speed"
        case map
        case startLatlng = "start_latlng"
        case gearId = "gear_id"
    }

    init(
        id: Int64,
        name: String,
        sportType: String,
        startDate: Date,
        distance: Double,
        movingTime: Int,
        elapsedTime: Int,
        totalElevationGain: Double,
        averageHeartrate: Double? = nil,
        averageWatts: Double? = nil,
        averageCadence: Double? = nil,
        averageSpeed: Double? = nil,
        map: StravaMap? = nil,
        startLatlng: [Double]? = nil,
        gearId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sportType = sportType
        self.startDate = startDate
        self.distance = distance
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.totalElevationGain = totalElevationGain
        self.averageHeartrate = averageHeartrate
        self.averageWatts = averageWatts
        self.averageCadence = averageCadence
        self.averageSpeed = averageSpeed
        self.map = map
        self.startLatlng = startLatlng
        self.gearId = gearId
    }
}

struct StravaMap: Decodable, Sendable {
    let summaryPolyline: String?

    enum CodingKeys: String, CodingKey {
        case summaryPolyline = "summary_polyline"
    }
}

struct StravaStreamSet: Decodable, Sendable {
    let time: [Int]?
    let distance: [Double]?
    let latlng: [[Double]]?
    let heartrate: [Double]?
    let cadence: [Double]?
    let watts: [Double]?
    let velocitySmooth: [Double]?
    let altitude: [Double]?

    private struct StreamWrapper<T: Decodable>: Decodable {
        let data: T
    }

    enum CodingKeys: String, CodingKey {
        case time
        case distance
        case latlng
        case heartrate
        case cadence
        case watts
        case velocitySmooth = "velocity_smooth"
        case altitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.time = try container.decodeIfPresent(StreamWrapper<[Int]>.self, forKey: .time)?.data
        self.distance = try container.decodeIfPresent(StreamWrapper<[Double]>.self, forKey: .distance)?.data
        self.latlng = try container.decodeIfPresent(StreamWrapper<[[Double]]>.self, forKey: .latlng)?.data
        self.heartrate = try container.decodeIfPresent(StreamWrapper<[Double]>.self, forKey: .heartrate)?.data
        self.cadence = try container.decodeIfPresent(StreamWrapper<[Double]>.self, forKey: .cadence)?.data
        self.watts = try container.decodeIfPresent(StreamWrapper<[Double]>.self, forKey: .watts)?.data
        self.velocitySmooth = try container.decodeIfPresent(StreamWrapper<[Double]>.self, forKey: .velocitySmooth)?.data
        self.altitude = try container.decodeIfPresent(StreamWrapper<[Double]>.self, forKey: .altitude)?.data
    }
}

struct StravaAthlete: Decodable, Sendable {
    let id: Int64
    let firstname: String?
    let lastname: String?
    let profile: String?
}

