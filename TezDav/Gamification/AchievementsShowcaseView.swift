// swiftlint:disable cyclomatic_complexity
import SwiftUI
import SwiftData

struct AchievementsShowcaseView: View {
    @Query(sort: \Achievement.dateEarned, order: .reverse) private var earnedAchievements: [Achievement]
    
    private var unlockedTypes: [String: Achievement] {
        var map: [String: Achievement] = [:]
        for ach in earnedAchievements {
            map[ach.type] = ach
        }
        return map
    }
    
    var body: some View {
        let isRussian = Locale.current.identifier.hasPrefix("ru")
        let allBadges = AchievementManager.shared.badges
        let unlocked = unlockedTypes
        
        ScrollView {
            VStack(spacing: 24) {
                // Progress Header Card
                VStack(spacing: 12) {
                    let earnedCount = earnedAchievements.count
                    let totalCount = allBadges.count
                    let percent = totalCount > 0 ? Double(earnedCount) / Double(totalCount) : 0.0
                    
                    Text(isRussian ? "Ваш прогресс наград" : "Your Achievements Progress")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.12), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(percent))
                                .stroke(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(earnedCount)/\(totalCount)")
                                .font(.title3.bold())
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isRussian ? "Уровень достижений" : "Achievement Level")
                                .font(.title3.bold())
                            
                            Text(levelName(earnedCount: earnedCount, isRussian: isRussian))
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.purple.gradient)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 10)
                )
                
                // Badges Grid
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(allBadges, id: \.type) { badge in
                        let earned = unlocked[badge.type]
                        let isUnlocked = earned != nil
                        
                        VStack(spacing: 12) {
                            // Badge Icon ZStack
                            ZStack {
                                Circle()
                                    .fill(isUnlocked ? badgeGradient(for: badge.type) : LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 72, height: 72)
                                    .shadow(color: isUnlocked ? badgeColor(for: badge.type).opacity(0.3) : .clear, radius: 8, y: 4)
                                
                                Text(badgeEmoji(for: badge.type))
                                    .font(.system(size: 36))
                                    .grayscale(isUnlocked ? 0.0 : 1.0)
                                    .opacity(isUnlocked ? 1.0 : 0.4)
                                
                                if isUnlocked {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green, .white)
                                        .font(.caption)
                                        .offset(x: 24, y: -24)
                                }
                            }
                            
                            Text(badge.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .foregroundColor(isUnlocked ? .primary : .secondary)
                            
                            Text(badge.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .frame(height: 48, alignment: .top)
                            
                            if let earned = earned {
                                Text(earned.dateEarned.formatted(date: .numeric, time: .omitted))
                                    .font(.caption2.bold())
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.08), in: Capsule())
                            } else {
                                Text(isRussian ? "Заблокировано" : "Locked")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.04), in: Capsule())
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .shadow(color: Color.black.opacity(isUnlocked ? 0.05 : 0.02), radius: 6)
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(isRussian ? "Награды и Значки" : "Badges & Rewards")
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private func levelName(earnedCount: Int, isRussian: Bool) -> String {
        if earnedCount >= 10 {
            return isRussian ? "Абсолютный чемпион" : "Grand Champion"
        } else if earnedCount >= 7 {
            return isRussian ? "Мастер спорта" : "Master Athlete"
        } else if earnedCount >= 4 {
            return isRussian ? "Продвинутый любитель" : "Advanced Amateur"
        } else if earnedCount >= 1 {
            return isRussian ? "Новичок" : "Novice"
        } else {
            return isRussian ? "В начале пути" : "Just Starting"
        }
    }
    
    private func badgeEmoji(for type: String) -> String {
        switch type {
        case "first_steps": return "👣"
        case "step_master": return "👟"
        case "mountain_goat": return "🐐"
        case "streak_7d": return "🔥"
        case "marathoner": return "🏅"
        case "speedy_mile": return "⚡️"
        case "road_knight": return "🚴‍♂️"
        case "deep_diver": return "🏊‍♂️"
        case "casual_start": return "🌱"
        case "super_active": return "⏱️"
        default: return "🏆"
        }
    }
    
    private func badgeColor(for type: String) -> Color {
        switch type {
        case "first_steps": return .green
        case "step_master": return .teal
        case "mountain_goat": return .brown
        case "streak_7d": return .orange
        case "marathoner": return .purple
        case "speedy_mile": return .yellow
        case "road_knight": return .blue
        case "deep_diver": return .indigo
        case "casual_start": return .green
        case "super_active": return .red
        default: return .blue
        }
    }
    
    private func badgeGradient(for type: String) -> LinearGradient {
        let base = badgeColor(for: type)
        return LinearGradient(
            colors: [base.opacity(0.2), base.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
