import UIKit

struct PacingWristbandExporter {
    
    static func render(
        title: String,
        targetDistance: String,
        targetTime: String,
        splits: [RaceSplit],
        isMetric: Bool
    ) -> UIImage {
        // Dimensions: optimized for a mobile screen / wristband preview (600 x 1400)
        let width: CGFloat = 600
        // Adjust height dynamically based on the number of splits (min 1000, max 2500)
        let headerHeight: CGFloat = 260
        let footerHeight: CGFloat = 100
        let rowHeight: CGFloat = 45
        let contentHeight = CGFloat(splits.count) * rowHeight
        let height = max(headerHeight + contentHeight + footerHeight, 900)
        
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 1. Draw Background Gradient (Deep slate to Dark navy)
            let colors = [
                UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1.0).cgColor,
                UIColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 1.0).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: height),
                options: []
            )
            
            // 2. Draw Orange Sidebar/Accents (Sports brand feel)
            let accentColor = UIColor(red: 0.98, green: 0.47, blue: 0.16, alpha: 1.0)
            cgContext.setFillColor(accentColor.cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: height))
            
            // 3. Draw Header Info
            let titleFont = UIFont.systemFont(ofSize: 28, weight: .black)
            let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .bold)
            let metaFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let timeFont = UIFont.systemFont(ofSize: 42, weight: .black)
            
            // App Name / Logo
            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: accentColor
            ]
            "TEZDAV PACING STRATEGY".draw(at: CGPoint(x: 40, y: 35), withAttributes: brandAttributes)
            
            // Target Name
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            let displayTitle = title.isEmpty ? "Целевой старт" : title
            displayTitle.draw(in: CGRect(x: 40, y: 70, width: width - 80, height: 40), withAttributes: titleAttributes)
            
            // Target Stats box
            let statsBgColor = UIColor(white: 1.0, alpha: 0.06)
            let statsRect = CGRect(x: 40, y: 120, width: width - 80, height: 100)
            cgContext.setFillColor(statsBgColor.cgColor)
            let clipPath = UIBezierPath(roundedRect: statsRect, cornerRadius: 12)
            cgContext.addPath(clipPath.cgPath)
            cgContext.fillPath()
            
            // Target distance
            let distAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor(white: 1.0, alpha: 0.6)
            ]
            "ДИСТАНЦИЯ: \(targetDistance)".draw(at: CGPoint(x: 60, y: 135), withAttributes: distAttributes)
            
            "ОЖИДАЕМОЕ ВРЕМЯ:".draw(at: CGPoint(x: 60, y: 160), withAttributes: distAttributes)
            
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: timeFont,
                .foregroundColor: UIColor.white
            ]
            targetTime.draw(at: CGPoint(x: 60, y: 175), withAttributes: timeAttributes)
            
            // 4. Draw Table Headers
            let tableStartY: CGFloat = 280
            let colWidths: [CGFloat] = [70, 140, 160, 150] // index, split, cumulative, elev
            let colOffsets: [CGFloat] = [40, 110, 250, 410]
            let unitName = isMetric ? "км" : "миля"
            
            let headerTextAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor(white: 1.0, alpha: 0.8)
            ]
            
            "#".draw(at: CGPoint(x: colOffsets[0], y: tableStartY), withAttributes: headerTextAttributes)
            "Темп сплита".draw(at: CGPoint(x: colOffsets[1], y: tableStartY), withAttributes: headerTextAttributes)
            "Общее время".draw(at: CGPoint(x: colOffsets[2], y: tableStartY), withAttributes: headerTextAttributes)
            "Набор (\(isMetric ? "м" : "фт"))".draw(at: CGPoint(x: colOffsets[3], y: tableStartY), withAttributes: headerTextAttributes)
            
            // Underline headers
            cgContext.setStrokeColor(UIColor(white: 1.0, alpha: 0.2).cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: 40, y: tableStartY + 25))
            cgContext.addLine(to: CGPoint(x: width - 40, y: tableStartY + 25))
            cgContext.strokePath()
            
            // 5. Draw Table Rows
            let cellFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
            let cellRegularFont = UIFont.systemFont(ofSize: 16, weight: .medium)
            
            let rowYStart = tableStartY + 35
            
            for (index, split) in splits.enumerated() {
                let rowY = rowYStart + CGFloat(index) * rowHeight
                
                // Zebra stripe backing
                if index % 2 == 0 {
                    cgContext.setFillColor(UIColor(white: 1.0, alpha: 0.03).cgColor)
                    cgContext.fill(CGRect(x: 40, y: rowY - 5, width: width - 80, height: rowHeight))
                }
                
                // Col 1: Split number
                let indexAttributes: [NSAttributedString.Key: Any] = [
                    .font: cellRegularFont,
                    .foregroundColor: UIColor(white: 1.0, alpha: 0.5)
                ]
                "\(split.number)".draw(at: CGPoint(x: colOffsets[0] + 5, y: rowY + 5), withAttributes: indexAttributes)
                
                // Calculate split pace: duration / distance_in_km_or_miles
                let segmentPaceFactor = split.splitDistance / (isMetric ? 1000.0 : 1609.344)
                let paceSec = split.splitDuration / segmentPaceFactor
                let paceMin = Int(paceSec) / 60
                let paceSecRemainder = Int(paceSec) % 60
                let paceString = String(format: "%d:%02d /%@", paceMin, paceSecRemainder, unitName)
                
                let paceAttributes: [NSAttributedString.Key: Any] = [
                    .font: cellFont,
                    .foregroundColor: accentColor
                ]
                paceString.draw(at: CGPoint(x: colOffsets[1], y: rowY + 5), withAttributes: paceAttributes)
                
                // Col 3: Cumulative Time
                let cumTime = formattedDurationHMS(split.cumulativeDuration)
                let timeCellAttributes: [NSAttributedString.Key: Any] = [
                    .font: cellFont,
                    .foregroundColor: UIColor.white
                ]
                cumTime.draw(at: CGPoint(x: colOffsets[2], y: rowY + 5), withAttributes: timeCellAttributes)
                
                // Col 4: Elevation gain (convert if imperial)
                let elevVal = isMetric ? split.elevationGain : split.elevationGain * 3.28084
                let elevString: String
                if elevVal > 0.5 {
                    elevString = String(format: "+%.0f", elevVal)
                } else {
                    elevString = "-"
                }
                let elevAttributes: [NSAttributedString.Key: Any] = [
                    .font: cellRegularFont,
                    .foregroundColor: elevVal > 0.5 ? UIColor(red: 0.34, green: 0.8, blue: 0.53, alpha: 1.0) : UIColor(white: 1.0, alpha: 0.3)
                ]
                elevString.draw(at: CGPoint(x: colOffsets[3] + 20, y: rowY + 5), withAttributes: elevAttributes)
            }
            
            // 6. Draw Footer
            let footerY = height - 70
            cgContext.setStrokeColor(UIColor(white: 1.0, alpha: 0.1).cgColor)
            cgContext.move(to: CGPoint(x: 40, y: footerY - 10))
            cgContext.addLine(to: CGPoint(x: width - 40, y: footerY - 10))
            cgContext.strokePath()
            
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: metaFont,
                .foregroundColor: UIColor(white: 1.0, alpha: 0.4)
            ]
            "Спланировано в TezDav • Учитывает CTL, рельеф и погоду".draw(
                at: CGPoint(x: 40, y: footerY + 10),
                withAttributes: footerAttributes
            )
        }
    }
    
    private static func formattedDurationHMS(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00:00"
    }
}
