import SwiftUI
import MapKit

struct RouteMapSnapshotView: View {
    let coordinates: [CLLocationCoordinate2D]
    let size: CGSize
    
    @State private var snapshotImage: UIImage? = nil
    
    init(coordinates: [CLLocationCoordinate2D], size: CGSize = CGSize(width: 300, height: 150)) {
        self.coordinates = coordinates
        self.size = size
    }
    
    var body: some View {
        Group {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                .onAppear {
                    generateSnapshot()
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(12)
        .clipped()
    }
    
    private func generateSnapshot() {
        guard !coordinates.isEmpty else { return }
        
        let options = MKMapSnapshotter.Options()
        
        // Find region bounding box
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        
        // Add 30% padding
        let latDelta = max(0.002, (maxLat - minLat) * 1.3)
        let lonDelta = max(0.002, (maxLon - minLon) * 1.3)
        
        options.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
        options.size = size
        options.scale = UIScreen.main.scale
        options.showsBuildings = true
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: .global()) { snapshot, error in
            guard let snapshot = snapshot, error == nil else { return }
            
            UIGraphicsBeginImageContextWithOptions(size, true, options.scale)
            snapshot.image.draw(at: .zero)
            
            if let context = UIGraphicsGetCurrentContext() {
                context.setLineWidth(4.0)
                context.setStrokeColor(UIColor.systemOrange.cgColor)
                context.setLineJoin(.round)
                context.setLineCap(.round)
                
                context.beginPath()
                var first = true
                for coord in coordinates {
                    let point = snapshot.point(for: coord)
                    // Ensure the point is within snapshot boundaries
                    if first {
                        context.move(to: point)
                        first = false
                    } else {
                        context.addLine(to: point)
                    }
                }
                context.strokePath()
                
                // Draw green dot for start, red dot for end
                if coordinates.count >= 2 {
                    let startPoint = snapshot.point(for: coordinates.first!)
                    let endPoint = snapshot.point(for: coordinates.last!)
                    
                    // Start Dot (Green)
                    context.setFillColor(UIColor.systemGreen.cgColor)
                    context.addArc(center: startPoint, radius: 5.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    context.fillPath()
                    
                    // End Dot (Red)
                    context.setFillColor(UIColor.systemRed.cgColor)
                    context.addArc(center: endPoint, radius: 5.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    context.fillPath()
                }
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                self.snapshotImage = finalImage
            }
        }
    }
}
