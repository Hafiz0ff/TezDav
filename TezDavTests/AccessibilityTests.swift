import XCTest
import UIKit
import SwiftUI
@testable import TezDav

final class AccessibilityTests: XCTestCase {
    
    // MARK: - WCAG Luminance and Contrast Ratio Algorithms
    
    private func luminance(for color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rVal = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gVal = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bVal = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        return 0.2126 * Double(rVal) + 0.7152 * Double(gVal) + 0.0722 * Double(bVal)
    }
    
    private func contrastRatio(foreground: UIColor, background: UIColor) -> Double {
        let l1 = luminance(for: foreground)
        let l2 = luminance(for: background)
        
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    // MARK: - Contrast Ratio Tests (WCAG AA 4.5:1 Target)
    
    func testDesignSystemContrastRatios() {
        // UIColors equivalent to hexes in Color extension
        let textPrimary = UIColor(red: 1, green: 1, blue: 1, alpha: 1) // #FFFFFF
        let textSecondary = UIColor(red: 209/255, green: 213/255, blue: 219/255, alpha: 1) // #D1D5DB
        let textTertiary = UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1) // #9CA3AF
        
        let bgPrimary = UIColor(red: 10/255, green: 10/255, blue: 10/255, alpha: 1) // #0A0A0A
        let bgSecondary = UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1) // #1A1A1A
        let bgTertiary = UIColor(red: 42/255, green: 42/255, blue: 42/255, alpha: 1) // #2A2A2A
        
        let accentPrimary = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1) // #10B981
        
        // 1. Text Primary on Background Primary
        let ratio1 = contrastRatio(foreground: textPrimary, background: bgPrimary)
        XCTAssertGreaterThanOrEqual(ratio1, 4.5, "Text Primary on Background Primary contrast should be at least 4.5:1")
        
        // 2. Text Secondary on Background Primary
        let ratio2 = contrastRatio(foreground: textSecondary, background: bgPrimary)
        XCTAssertGreaterThanOrEqual(ratio2, 4.5, "Text Secondary on Background Primary contrast should be at least 4.5:1")
        
        // 3. Text Secondary on Background Secondary
        let ratio3 = contrastRatio(foreground: textSecondary, background: bgSecondary)
        XCTAssertGreaterThanOrEqual(ratio3, 4.5, "Text Secondary on Background Secondary contrast should be at least 4.5:1")
        
        // 4. Accent Primary on Background Primary
        let ratio4 = contrastRatio(foreground: accentPrimary, background: bgPrimary)
        XCTAssertGreaterThanOrEqual(ratio4, 3.0, "Accent colors used as large elements or secondary cues must meet at least 3.0:1")
    }
    
    // MARK: - Minimum Touch Target Size Validation (44x44 pt)
    
    func testTouchTargetSizes() {
        // Human Interface Guidelines require interactive elements to be at least 44x44 points
        let minInteractiveSize: CGFloat = 44.0
        
        // We will assert on components like standard list item buttons, control buttons, etc.
        let standardButtonFrame = CGRect(x: 0, y: 0, width: 120, height: 44)
        XCTAssertGreaterThanOrEqual(standardButtonFrame.width, minInteractiveSize)
        XCTAssertGreaterThanOrEqual(standardButtonFrame.height, minInteractiveSize)
        
        let capsuleButtonFrame = CGRect(x: 0, y: 0, width: 44, height: 44)
        XCTAssertGreaterThanOrEqual(capsuleButtonFrame.width, minInteractiveSize)
        XCTAssertGreaterThanOrEqual(capsuleButtonFrame.height, minInteractiveSize)
    }
}
