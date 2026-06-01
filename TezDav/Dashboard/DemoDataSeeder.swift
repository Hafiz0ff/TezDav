import Foundation
import SwiftData
import CoreLocation

enum DemoDataSeeder {
    static func seedAllDemoData(modelContext: ModelContext) {
        // 1. Clear any existing data to avoid duplicates or conflicts
        clearAllData(modelContext: modelContext)
        
        // 2. Setup user settings
        let settings = UserSettings()
        settings.mainSport = "Run"
        settings.appMode = .pro
        settings.isMetric = true
        settings.birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        settings.maxHeartRate = 185.0
        settings.restingHeartRate = 58.0
        settings.cyclingFTP = 265.0
        settings.targetWeeklyDistanceMeters = 50000.0
        settings.targetWeeklyActiveMinutes = 180.0
        modelContext.insert(settings)
        
        // 3. Save a mock Strava token to Keychain
        let mockToken = StravaToken(
            accessToken: "demo_access_token",
            refreshToken: "demo_refresh_token",
            expiresAt: Date().addingTimeInterval(3600 * 24 * 365) // 1 year expiry
        )
        try? KeychainTokenStore().saveToken(mockToken)
        
        // 4. Seed Gear items
        let runShoes = GearItem(
            name: "Nike Pegasus 40",
            sportType: "Run",
            gearType: "shoes",
            brand: "Nike",
            startDate: Date().addingTimeInterval(-86400 * 60),
            maxDistanceKm: 800.0,
            currentDistanceKm: 145.2,
            isActive: true
        )
        modelContext.insert(runShoes)
        
        let roadBike = GearItem(
            name: "Specialized Tarmac SL8",
            sportType: "Ride",
            gearType: "bike",
            brand: "Specialized",
            startDate: Date().addingTimeInterval(-86400 * 120),
            maxDistanceKm: 5000.0,
            currentDistanceKm: 1240.0,
            isActive: true
        )
        modelContext.insert(roadBike)
        
        // 5. Generate coordinates and polylines in Dushanbe, Tajikistan
        // Dushanbe center: lat 38.56, lng 68.79
        let centerLat = 38.56
        let centerLng = 68.79
        
        // Helper to generate a loop polyline
        func generateDushanbePolyline(radiusOffset: Double = 0.0) -> String {
            var coords: [CLLocationCoordinate2D] = []
            for i in 0..<60 {
                let angle = Double(i) * (2.0 * .pi / 60.0)
                let lat = centerLat + (0.015 + radiusOffset) * sin(angle)
                let lng = centerLng + (0.015 + radiusOffset) * cos(angle)
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return PolylineEncoder.encode(coordinates: coords)
        }
        
        // 6. Seed Activities for the past 30 days (to build a beautiful PMC chart)
        let calendar = Calendar.current
        let today = Date()
        
        // We will seed 12 activities spaced out
        for dayOffset in [28, 25, 23, 20, 18, 15, 12, 10, 8, 5, 3, 1] {
            guard let startDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            let isRide = dayOffset % 6 == 0
            let isWalk = dayOffset % 7 == 0
            
            let id = Int64(100000 + dayOffset)
            let sport = isRide ? "Ride" : (isWalk ? "Walk" : "Run")
            let name = isRide ? "Варзобское ущелье Вело" : (isWalk ? "Прогулка по парку Рудаки" : "Утренний кросс Душанбе")
            
            let distance = isRide ? 35000.0 : (isWalk ? 5200.0 : 8500.0)
            let duration = isRide ? 5400.0 : (isWalk ? 3600.0 : 2550.0)
            let hr = isRide ? 135.0 : (isWalk ? 98.0 : 148.0)
            let power = isRide ? 210.0 : nil
            let load = isRide ? 110.0 : (isWalk ? 20.0 : 65.0)
            
            let activity = Activity(
                stravaId: id,
                sportType: sport,
                name: name,
                startDate: startDate,
                distanceMeters: distance,
                movingTime: duration,
                elapsedTime: duration + 120,
                elevationGain: isRide ? 420.0 : (isWalk ? 15.0 : 80.0),
                averageHeartRate: hr,
                averagePower: power,
                averageCadence: isRide ? 88.0 : (isWalk ? nil : 172.0),
                averageSpeed: distance / duration,
                encodedPolyline: generateDushanbePolyline(radiusOffset: Double(dayOffset) * 0.001),
                trimp: load * 0.9,
                trainingLoad: load,
                importedAt: today,
                streamsImported: true,
                source: "strava"
            )
            
            modelContext.insert(activity)
            
            // Seed weather snapshot for some activities
            if dayOffset % 2 == 0 {
                let weather = WeatherSnapshot(
                    temperature: 22.0 + Double(dayOffset % 5),
                    humidity: 45.0 + Double(dayOffset % 10),
                    windSpeed: 2.5,
                    condition: "Sunny",
                    latitude: centerLat,
                    longitude: centerLng,
                    date: startDate
                )
                modelContext.insert(weather)
            }
            
            // Seed a few stream samples for the last activity to support detailed charts
            if dayOffset == 1 {
                let count = 30
                for i in 0..<count {
                    let offset = Double(i) * (duration / Double(count))
                    let dist = Double(i) * (distance / Double(count))
                    let sample = ActivityStreamSample(
                        activityId: id,
                        offsetSeconds: Int(offset),
                        distanceMeters: dist,
                        latitude: centerLat + 0.01 * sin(Double(i) * 0.2),
                        longitude: centerLng + 0.01 * cos(Double(i) * 0.2),
                        heartRate: 130.0 + Double(i % 5) * 3.0,
                        cadence: isRide ? 85.0 + Double(i % 3) : 165.0 + Double(i % 5),
                        power: isRide ? 200.0 + Double(i % 4) * 15.0 : nil,
                        speed: distance / duration,
                        altitude: 800.0 + Double(i) * 1.5
                    )
                    modelContext.insert(sample)
                }
            }
        }
        
        // 7. Seed Achievements
        let ach1 = Achievement(
            type: "run_5k",
            dateEarned: calendar.date(byAdding: .day, value: -15, to: today) ?? today,
            title: "Быстрая пятерка",
            descriptionText: "Преодолел дистанцию 5 км быстрее чем за 22 минуты."
        )
        modelContext.insert(ach1)
        
        let ach2 = Achievement(
            type: "streak_7d",
            dateEarned: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
            title: "Спортивная неделя",
            descriptionText: "Выполнял тренировки 7 дней подряд без перерывов."
        )
        modelContext.insert(ach2)
        
        let ach3 = Achievement(
            type: "altitude_1000",
            dateEarned: calendar.date(byAdding: .day, value: -6, to: today) ?? today,
            title: "Горный король",
            descriptionText: "Набрал суммарно 1000 метров вертикального подъема."
        )
        modelContext.insert(ach3)
        
        // 8. Seed Friend activities (Social Feed)
        let friend1 = FriendActivity(
            friendName: "Даврон Каримов",
            friendAvatar: "ДК",
            sportType: "Run",
            title: "Вечерний забег по проспекту Исмоили Сомони",
            distanceMeters: 12500.0,
            durationSeconds: 3420.0,
            startDate: calendar.date(byAdding: .hour, value: -4, to: today) ?? today,
            encodedPolyline: generateDushanbePolyline(radiusOffset: 0.003),
            kudosCount: 4,
            hasKudosByMe: true
        )
        modelContext.insert(friend1)
        
        let comment1 = FriendComment(
            authorName: "Фируз Хафизов",
            text: "Отличный темп, Даврон! Держишь форму.",
            createdAt: calendar.date(byAdding: .hour, value: -3, to: today) ?? today
        )
        comment1.friendActivity = friend1
        modelContext.insert(comment1)
        
        let friend2 = FriendActivity(
            friendName: "Ситора Алиева",
            friendAvatar: "СА",
            sportType: "Ride",
            title: "Варзобское ущелье - тяжелый подъем",
            distanceMeters: 48000.0,
            durationSeconds: 7800.0,
            startDate: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            encodedPolyline: generateDushanbePolyline(radiusOffset: -0.002),
            kudosCount: 7,
            hasKudosByMe: false
        )
        modelContext.insert(friend2)
        
        let comment2 = FriendComment(
            authorName: "Даврон Каримов",
            text: "Крутой подъем! В следующий раз едем вместе.",
            createdAt: calendar.date(byAdding: .hour, value: -18, to: today) ?? today
        )
        comment2.friendActivity = friend2
        modelContext.insert(comment2)
        
        // 9. Seed Saved routes
        let route = SavedRoute(
            name: "Маршрут Душанбе - Варзоб ГЭС",
            createdAt: calendar.date(byAdding: .day, value: -10, to: today) ?? today,
            sportType: "Ride",
            totalDistanceMeters: 22000.0,
            totalElevationGain: 310.0,
            totalElevationLoss: 50.0,
            estimatedTimeSeconds: 3600.0
        )
        
        var routePoints: [CLLocationCoordinate2D] = []
        for i in 0..<50 {
            let lat = centerLat + Double(i) * 0.001
            let lng = centerLng + Double(i) * 0.0005
            routePoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        route.routeCoordinates = routePoints
        route.waypoints = [routePoints.first!, routePoints.last!]
        
        var elevProfile: [ElevationPoint] = []
        for i in 0..<50 {
            elevProfile.append(ElevationPoint(distance: Double(i) * 440.0, elevation: 800.0 + Double(i) * 6.0))
        }
        route.elevationProfile = elevProfile
        modelContext.insert(route)
        
        // 10. Seed Planned Workouts for the current week
        let plan1 = PlannedWorkout(
            date: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
            sportType: "Run",
            title: "Темповая тренировка 45'",
            plannedDurationSeconds: 2700.0,
            plannedDistanceMeters: 10000.0,
            plannedTSS: 50.0,
            isCompleted: false
        )
        modelContext.insert(plan1)
        
        let plan2 = PlannedWorkout(
            date: calendar.date(byAdding: .day, value: 3, to: today) ?? today,
            sportType: "Ride",
            title: "Длинный выезд (Варзоб)",
            plannedDurationSeconds: 7200.0,
            plannedDistanceMeters: 55000.0,
            plannedTSS: 120.0,
            isCompleted: false
        )
        modelContext.insert(plan2)
        
        // 11. Run recurrent load calculations to initialize PMC values properly
        Task {
            await TrainingLoadCalculator.recalculateAllActivities(context: modelContext, settings: settings)
        }
    }
    
    private static func clearAllData(modelContext: ModelContext) {
        // Clear UserSettings, Activities, and associated models
        try? modelContext.delete(model: UserSettings.self)
        try? modelContext.delete(model: Activity.self)
        try? modelContext.delete(model: ActivityStreamSample.self)
        try? modelContext.delete(model: GearItem.self)
        try? modelContext.delete(model: WeatherSnapshot.self)
        try? modelContext.delete(model: Achievement.self)
        try? modelContext.delete(model: FriendActivity.self)
        try? modelContext.delete(model: FriendComment.self)
        try? modelContext.delete(model: SavedRoute.self)
        try? modelContext.delete(model: PlannedWorkout.self)
        try? modelContext.save()
    }
}
