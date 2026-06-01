import Foundation
import CoreSpotlight
import MobileCoreServices

final class CoreSpotlightManager {
    static let shared = CoreSpotlightManager()
    
    private init() {}
    
    struct IndexableActivity {
        let name: String
        let distanceMeters: Double
        let movingTime: Double
        let startDate: Date
        let sportType: String
        let best5kTime: Double?
        let best10kTime: Double?
        let peakPower20m: Double?
        let stravaId: Int64
    }
    
    /// Indexes a collection of activities in Spotlight.
    /// Runs asynchronously on a background queue.
    func indexActivities(_ activities: [Activity]) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        
        let indexables = activities.map { activity in
            IndexableActivity(
                name: activity.name,
                distanceMeters: activity.distanceMeters,
                movingTime: activity.movingTime,
                startDate: activity.startDate,
                sportType: activity.sportType,
                best5kTime: activity.best5kTime,
                best10kTime: activity.best10kTime,
                peakPower20m: activity.peakPower20m,
                stravaId: activity.stravaId
            )
        }
        
        DispatchQueue.global(qos: .background).async {
            var items: [CSSearchableItem] = []
            let isRu = Locale.current.identifier.hasPrefix("ru")
            
            for activity in indexables {
                let attributeSet = CSSearchableItemAttributeSet(itemContentType: "public.item")
                
                attributeSet.title = activity.name
                
                let distKm = activity.distanceMeters / 1000.0
                
                let durationMinutes = Int(activity.movingTime) / 60
                let dateStr = DateFormatter.localizedString(from: activity.startDate, dateStyle: .medium, timeStyle: .none)
                
                let sportName = isRu ? 
                    (activity.sportType.lowercased() == "run" ? "Бег" : "Велосипед") : 
                    activity.sportType
                
                var desc = isRu ?
                    "\(sportName) от \(dateStr). Дистанция: \(String(format: "%.1f", distKm)) км. Время: \(durationMinutes) мин." :
                    "\(sportName) on \(dateStr). Distance: \(String(format: "%.1f", distKm)) km. Duration: \(durationMinutes) min."
                
                // Add personal records info if applicable
                var records: [String] = []
                if activity.best5kTime != nil { records.append(isRu ? "Рекорд на 5 км" : "5k PR") }
                if activity.best10kTime != nil { records.append(isRu ? "Рекорд на 10 км" : "10k PR") }
                if activity.peakPower20m != nil { records.append(isRu ? "Пик 20 мин мощности" : "20m Peak Power") }
                
                if !records.isEmpty {
                    desc += isRu ? " Достижения: \(records.joined(separator: ", "))" : " Achievements: \(records.joined(separator: ", "))"
                }
                
                attributeSet.contentDescription = desc
                attributeSet.keywords = [activity.sportType, "workout", activity.name, "tezdav", isRu ? "тренировка" : "exercise"]
                
                let uniqueIdentifier = "activity-\(activity.stravaId)"
                let item = CSSearchableItem(
                    uniqueIdentifier: uniqueIdentifier,
                    domainIdentifier: "com.example.TezDav.activities",
                    attributeSet: attributeSet
                )
                items.append(item)
            }
            
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error = error {
                    print("Spotlight indexing error: \(error.localizedDescription)")
                } else {
                    print("Spotlight successfully indexed \(items.count) items.")
                }
            }
        }
    }
    
    /// Deletes specific activity from Spotlight index.
    func deindexActivity(id: Int64) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["activity-\(id)"]) { error in
            if let error = error {
                print("Spotlight de-indexing error: \(error)")
            }
        }
    }
}
