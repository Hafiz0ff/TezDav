import SwiftUI
import CoreLocation
import SwiftData

struct SocialFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FriendActivity.startDate, order: .reverse) private var feedActivities: [FriendActivity]
    @Query private var userSettingsList: [UserSettings]
    
    @State private var newCommentTexts: [UUID: String] = [:]
    @State private var animateKudos: [UUID: Bool] = [:]
    
    private var isMetric: Bool {
        userSettingsList.first?.isMetric ?? true
    }
    
    private var myName: String {
        userSettingsList.first?.stravaAccountName ?? "Спортсмен"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.04)
                    .ignoresSafeArea()
                
                if feedActivities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Нет активности друзей")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        Text("Ваши друзья пока не добавили тренировок.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(feedActivities) { activity in
                                friendActivityCard(for: activity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Лента друзей")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.08, green: 0.08, blue: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                SyncService.seedFriendActivitiesIfNeeded(context: modelContext)
            }
        }
    }
    
    @ViewBuilder
    private func friendActivityCard(for activity: FriendActivity) -> some View {
        let coords = activity.encodedPolyline.map { PolylineEncoder.decode(polyline: $0) } ?? []
        
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                // Header: Avatar, Name, Time, Sport
                HStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(colors: [Color.orange, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(activity.friendAvatar)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.friendName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(timeAgo(from: activity.startDate))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: sportIcon(for: activity.sportType))
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Circle())
                }
                
                // Workout Title
                Text(activity.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Mini statistics row
                HStack(spacing: 12) {
                    statBlock(title: "ДИСТАНЦИЯ", value: formatDistance(activity.distanceMeters))
                    statBlock(title: "ВРЕМЯ", value: formatDuration(activity.durationSeconds))
                    statBlock(title: "ТЕМП / СКОРОСТЬ", value: formatPaceOrSpeed(activity: activity))
                }
                
                // Map visualization
                if !coords.isEmpty {
                    if NSClassFromString("XCTestCase") == nil {
                        TezDavMapView(
                            coordinates: coords,
                            sportType: activity.sportType,
                            showStartEndMarkers: false
                        )
                        .frame(height: 150)
                        .cornerRadius(12)
                        .disabled(true)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                            .frame(height: 150)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "map")
                                        .font(.title)
                                        .foregroundColor(.orange)
                                    Text("Карта загружена")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Actions (Kudos & Comments Count)
                HStack(spacing: 24) {
                    Button(action: {
                        toggleKudos(for: activity)
                    }) {
                        Label {
                            Text("\(activity.kudosCount)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(activity.hasKudosByMe ? .orange : .gray)
                        } icon: {
                            Image(systemName: activity.hasKudosByMe ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(activity.hasKudosByMe ? .orange : .gray)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Label {
                        Text("\(activity.comments.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    } icon: {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // Comments List & Input
                VStack(alignment: .leading, spacing: 10) {
                    if !activity.comments.isEmpty {
                        ForEach(activity.comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
                            HStack(alignment: .top, spacing: 6) {
                                Text(comment.authorName + ":")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.orange)
                                Text(comment.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    // Comment input field
                    HStack {
                        TextField("Написать комментарий...", text: Binding(
                            get: { newCommentTexts[activity.id] ?? "" },
                            set: { newCommentTexts[activity.id] = $0 }
                        ))
                        .font(.system(size: 13))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        
                        Button(action: {
                            addComment(to: activity)
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.orange)
                                .padding(8)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(8)
                        }
                        .disabled((newCommentTexts[activity.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(16)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Rectangle())
            // Double Tap gesture for Kudos
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        triggerDoubleTapKudos(for: activity)
                    }
            )
            
            // Pop-up Kudos Animation
            if animateKudos[activity.id] ?? false {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 72, weight: .black))
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.6), radius: 16)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }
        }
    }
    
    @ViewBuilder
    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
        .cornerRadius(10)
    }
    
    // MARK: - Logic & Actions
    
    private func toggleKudos(for activity: FriendActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if activity.hasKudosByMe {
            activity.kudosCount = max(0, activity.kudosCount - 1)
            activity.hasKudosByMe = false
        } else {
            activity.kudosCount += 1
            activity.hasKudosByMe = true
        }
        try? modelContext.save()
    }
    
    private func triggerDoubleTapKudos(for activity: FriendActivity) {
        if !activity.hasKudosByMe {
            toggleKudos(for: activity)
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            animateKudos[activity.id] = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                animateKudos[activity.id] = false
            }
        }
    }
    
    private func addComment(to activity: FriendActivity) {
        guard let text = newCommentTexts[activity.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        
        let comment = FriendComment(authorName: myName, text: text)
        activity.comments.append(comment)
        modelContext.insert(comment)
        
        newCommentTexts[activity.id] = ""
        try? modelContext.save()
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Helpers
    
    private func sportIcon(for sport: String) -> String {
        switch sport {
        case "Run": return "figure.run"
        case "Ride": return "bicycle"
        case "Walk": return "figure.walk"
        case "Swim": return "figure.pool.swim"
        default: return "figure.mixed.cardio"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let divider = isMetric ? 1000.0 : 1609.34
        let unit = isMetric ? "км" : "миль"
        return String(format: "%.2f %@", meters / divider, unit)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let hours = mins / 60
        let remMins = mins % 60
        if hours > 0 {
            return String(format: "%dч %02dм", hours, remMins)
        } else {
            return String(format: "%dм", remMins)
        }
    }
    
    private func formatPaceOrSpeed(activity: FriendActivity) -> String {
        let meters = activity.distanceMeters
        let seconds = activity.durationSeconds
        guard meters > 0 && seconds > 0 else { return isMetric ? "0:00 /км" : "0:00 /милю" }
        
        if activity.sportType == "Ride" {
            let dist = meters / (isMetric ? 1000.0 : 1609.34)
            let speed = dist / (seconds / 3600.0)
            let unit = isMetric ? "км/ч" : "миль/ч"
            return String(format: "%.1f %@", speed, unit)
        } else {
            let dist = meters / (isMetric ? 1000.0 : 1609.34)
            let pace = seconds / dist
            let paceMins = Int(pace) / 60
            let paceSecs = Int(pace) % 60
            let unit = isMetric ? "/км" : "/милю"
            return String(format: "%d:%02d %@", paceMins, paceSecs, unit)
        }
    }
    
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date.now.timeIntervalSince(date)
        if seconds < 60 {
            return "Только что"
        }
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return String(format: "%d мин. назад", minutes)
        }
        let hours = minutes / 60
        if hours < 24 {
            return String(format: "%d ч. назад", hours)
        }
        let days = hours / 24
        return String(format: "%d дн. назад", days)
    }
}
