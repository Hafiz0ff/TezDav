import SwiftUI
import CoreLocation

struct LiveSegmentOverlayView: View {
    @ObservedObject var coordinator = LiveSegmentCoordinator.shared
    
    private let neonOrange = Color(red: 1.0, green: 0.48, blue: 0.0)
    
    var body: some View {
        if let segment = coordinator.activeSegment {
            ZStack {
                // Glassmorphic dark full-screen overlay
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Image(systemName: segment.sportType.lowercased().contains("ride") ? "bicycle" : "figure.run")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("ЖИВОЙ СЕГМЕНТ")
                            .font(.headline.bold())
                            .foregroundColor(.orange)
                            .tracking(2.0)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Text(segment.name)
                        .font(.title2.weight(.black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    if coordinator.segmentCompleted {
                        // Segment Finished Banner
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                                .scaleEffect(1.1)
                                .shadow(color: .green.opacity(0.4), radius: 10)
                            
                            Text("ФИНИШ!")
                                .font(.system(.title, design: .rounded).weight(.black))
                                .foregroundColor(.white)
                            
                            Text(String(format: "Время: %.1f сек", coordinator.elapsedSegmentTime))
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white.opacity(0.9))
                            
                            if coordinator.timeAheadBehind < 0 {
                                Text("🔥 НОВЫЙ РЕКОРД СЕГМЕНТА! 🔥")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.15), in: Capsule())
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Live HUD Info
                        VStack(spacing: 8) {
                            let gap = coordinator.timeAheadBehind
                            let isAhead = gap <= 0
                            
                            Text(isAhead ? "ОПЕРЕЖЕНИЕ" : "ОТСТАВАНИЕ")
                                .font(.caption.weight(.bold))
                                .foregroundColor(isAhead ? neonOrange : .red)
                                .tracking(1.0)
                            
                            HStack(spacing: 4) {
                                Text(String(format: "%@%.1fс", isAhead ? "-" : "+", abs(gap)))
                                    .font(.system(size: 72, weight: .black, design: .rounded))
                                    .foregroundColor(isAhead ? neonOrange : .red)
                                    .shadow(color: (isAhead ? neonOrange : Color.red).opacity(0.3), radius: 15)
                            }
                        }
                        
                        // Dual progress Race Bar
                        VStack(spacing: 8) {
                            HStack {
                                Text(String(format: "Пройдено: %.0f м", coordinator.distanceCovered))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(String(format: "Осталось: %.0f м", coordinator.distanceRemaining))
                                    .font(.caption.bold())
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 24)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Track
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 8)
                                    
                                    // User progress
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(
                                            colors: [neonOrange, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: geo.size.width * CGFloat(coordinator.segmentProgress), height: 8)
                                    
                                    // KOM Leader indicator
                                    let komProgress = min(1.0, coordinator.elapsedSegmentTime / coordinator.targetTime)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yellow)
                                        .offset(x: geo.size.width * CGFloat(komProgress) - 7, y: -16)
                                        .shadow(color: .yellow.opacity(0.4), radius: 4)
                                    
                                    // User indicator
                                    Image(systemName: segment.sportType.lowercased().contains("ride") ? "bicycle" : "figure.run")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(neonOrange, in: Circle())
                                        .offset(x: geo.size.width * CGFloat(coordinator.segmentProgress) - 11, y: 12)
                                        .shadow(color: neonOrange.opacity(0.4), radius: 4)
                                }
                            }
                            .frame(height: 40)
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer()
                    
                    // Stats footer grid
                    Grid(horizontalSpacing: 24, verticalSpacing: 16) {
                        GridRow {
                            VStack(alignment: .center, spacing: 4) {
                                Text("КОМ/Рекорд")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1fс", coordinator.targetTime))
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Мое время")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1fс", coordinator.elapsedSegmentTime))
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Длина")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0fм", segment.distanceMeters))
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: coordinator.segmentProgress)
            .animation(.easeInOut, value: coordinator.segmentCompleted)
        }
    }
}
