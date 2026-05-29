import UIKit

struct HapticManager {
    /// Triggers standard impact feedback vibrations (light, medium, heavy, rigid).
    static func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // Ensure execution happens strictly on the Main/UI thread
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    /// Triggers a positive/success notification vibration pattern.
    static func success() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
    
    /// Triggers an attention/warning notification vibration pattern.
    static func warning() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }
    }
}
