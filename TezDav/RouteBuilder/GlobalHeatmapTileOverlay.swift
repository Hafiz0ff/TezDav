import Foundation
import MapKit

final class GlobalHeatmapTileOverlay: MKTileOverlay {
    let tracks: [HeatmapTrack]
    let filterSport: String
    let periodDays: Int?
    let colorScheme: PersonalHeatmapView.HeatmapColorScheme
    let opacity: Double
    let lineWidth: Double
    
    init(
        tracks: [HeatmapTrack],
        filterSport: String,
        periodDays: Int?,
        colorScheme: PersonalHeatmapView.HeatmapColorScheme,
        opacity: Double,
        lineWidth: Double
    ) {
        self.tracks = tracks
        self.filterSport = filterSport
        self.periodDays = periodDays
        self.colorScheme = colorScheme
        self.opacity = opacity
        self.lineWidth = lineWidth
        super.init(urlTemplate: nil)
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        // Render in background to prevent blocking map scrolling on the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.renderTile(at: path, result: result)
        }
    }
    
    private func renderTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let bounds = tileBounds(x: path.x, y: path.y, z: path.z)
        
        var matchedPoints: [(coord: CLLocationCoordinate2D, id: Int64)] = []
        
        for track in tracks {
            // Filter by sport
            if filterSport != "All" && track.sportType != filterSport { continue }
            
            for coord in track.coordinates {
                if coord.latitude >= bounds.minLat && coord.latitude <= bounds.maxLat &&
                   coord.longitude >= bounds.minLng && coord.longitude <= bounds.maxLng {
                    matchedPoints.append((coord: coord, id: track.id))
                }
            }
        }
        
        if matchedPoints.isEmpty {
            result(nil, nil)
            return
        }
        
        // Define grid cell sizes (approx 20 meters at current latitude)
        let gridSize = 32
        var grid = [String: Set<Int64>]()
        
        for pt in matchedPoints {
            let xPct = (pt.coord.longitude - bounds.minLng) / (bounds.maxLng - bounds.minLng)
            let yPct = (bounds.maxLat - pt.coord.latitude) / (bounds.maxLat - bounds.minLat)
            
            let gx = max(0, min(gridSize - 1, Int(xPct * Double(gridSize))))
            let gy = max(0, min(gridSize - 1, Int(yPct * Double(gridSize))))
            
            let key = "\(gx),\(gy)"
            grid[key, default: []].insert(pt.id)
        }
        
        let maxCount = grid.values.map { $0.count }.max() ?? 1
        
        // Create 256x256 pixel tile context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 256, height: 256), false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            result(nil, nil)
            return
        }
        
        let cellWidth = 256.0 / Double(gridSize)
        
        for (key, trackIds) in grid {
            let parts = key.split(separator: ",")
            guard parts.count == 2,
                  let gx = Int(parts[0]),
                  let gy = Int(parts[1]) else { continue }
            
            let count = trackIds.count
            let intensity = Double(count) / Double(maxCount)
            
            let color = getHeatColor(intensity: intensity)
            
            let centerX = (Double(gx) + 0.5) * cellWidth
            let centerY = (Double(gy) + 0.5) * cellWidth
            
            // Render circle representing heat
            let radius = cellWidth * (0.85 + intensity * 0.95)
            
            context.saveGState()
            
            let alpha = CGFloat(opacity * (0.25 + intensity * 0.75))
            context.setFillColor(color.withAlphaComponent(alpha).cgColor)
            context.addEllipse(in: CGRect(
                x: centerX - radius,
                y: centerY - radius,
                width: radius * 2.0,
                height: radius * 2.0
            ))
            context.fillPath()
            
            context.restoreGState()
        }
        
        let tileImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let data = tileImage?.pngData() {
            result(data, nil)
        } else {
            result(nil, nil)
        }
    }
    
    private func tileBounds(x: Int, y: Int, z: Int) -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) {
        let n = Double(1 << z)
        let minLng = Double(x) / n * 360.0 - 180.0
        let maxLng = Double(x + 1) / n * 360.0 - 180.0
        
        let minLatRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y + 1) / n)))
        let maxLatRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y) / n)))
        
        let minLat = minLatRad * 180.0 / .pi
        let maxLat = maxLatRad * 180.0 / .pi
        
        return (minLat, maxLat, minLng, maxLng)
    }
    
    private func getHeatColor(intensity: Double) -> UIColor {
        switch colorScheme {
        case .orange:
            if intensity < 0.35 {
                return UIColor.orange.withAlphaComponent(0.65)
            } else if intensity < 0.75 {
                return UIColor.systemOrange
            } else {
                return UIColor.yellow
            }
        case .green:
            if intensity < 0.35 {
                return UIColor.green.withAlphaComponent(0.65)
            } else if intensity < 0.75 {
                return UIColor.systemGreen
            } else {
                return UIColor.yellow
            }
        case .blue:
            if intensity < 0.35 {
                return UIColor.systemBlue.withAlphaComponent(0.65)
            } else if intensity < 0.75 {
                return UIColor.cyan
            } else {
                return UIColor.white
            }
        case .multisport:
            // Custom sunset pink/purple to orange
            if intensity < 0.35 {
                return UIColor.systemPurple.withAlphaComponent(0.65)
            } else if intensity < 0.75 {
                return UIColor.systemPink
            } else {
                return UIColor.orange
            }
        }
    }
}
