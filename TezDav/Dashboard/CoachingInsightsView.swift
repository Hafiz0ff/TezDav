import SwiftUI
import SwiftData

struct DailyRecommendationCardView: View {
    let activities: [Activity]
    let settings: UserSettings
    let context: ModelContext
    
    @Query(sort: \GearItem.startDate, order: .reverse) private var gears: [GearItem]
    @State private var insights: [CoachingInsight] = []
    @State private var isExpanded = false
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        
        VStack(alignment: .leading, spacing: 12) {
            if insights.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.title)
                        .foregroundStyle(.purple.gradient)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isRussian ? "ИИ-Тренер TezDav" : "TezDav AI Coach")
                            .font(.headline)
                        Text(isRussian ? "Ваш тренировочный баланс идеален. Новых советов пока нет." : "Your training balance is optimal. No new alerts.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .onAppear {
                    loadInsights()
                }
            } else {
                let daily = insights.first!
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: categoryIcon(daily.category))
                            .font(.title2)
                            .foregroundStyle(categoryColor(daily.category).gradient)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isRussian ? daily.titleRu : daily.titleEn)
                                .font(.headline)
                            Text(isRussian ? "Совет дня от ИИ" : "Daily AI Advice")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(categoryColor(daily.category))
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(isRussian ? daily.messageRu : daily.messageEn)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if isExpanded {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isRussian ? "Научное обоснование:" : "Scientific Rationale:")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(isRussian ? daily.rationaleRu : daily.rationaleEn)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        NavigationLink(destination: CoachingInsightsArchiveView(insights: insights)) {
                            Text(isRussian ? "Показать историю советов" : "View Insights Archive")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.purple)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .onAppear {
            loadInsights()
        }
    }
    
    private func loadInsights() {
        insights = CoachingEngine.generateInsights(
            activities: activities,
            settings: settings,
            gears: gears
        )
    }
    
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "safety": return "exclamationmark.shield.fill"
        case "recovery": return "bed.double.fill"
        case "gear": return "shoeprints.fill"
        case "progress": return "chart.xyaxis.line"
        default: return "figure.run.circle.fill"
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "safety": return .red
        case "recovery": return .blue
        case "gear": return .orange
        case "progress": return .purple
        default: return .green
        }
    }
}

// MARK: - Archive View
struct CoachingInsightsArchiveView: View {
    let insights: [CoachingInsight]
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        
        List {
            if insights.count <= 1 {
                Section {
                    Text(isRussian ? "История пуста. Советы будут накапливаться по мере изменения нагрузок." : "Archive is empty. New recommendations accumulate dynamically.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(insights.dropFirst()) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: categoryIcon(item.category))
                                .foregroundStyle(categoryColor(item.category))
                            Text(isRussian ? item.titleRu : item.titleEn)
                                .font(.headline)
                            Spacer()
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(isRussian ? item.messageRu : item.messageEn)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Divider()
                            .padding(.top, 4)
                        
                        Text(isRussian ? item.rationaleRu : item.rationaleEn)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(isRussian ? "Архив ИИ-советов" : "Coaching Archive")
    }
    
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "safety": return "exclamationmark.shield.fill"
        case "recovery": return "bed.double.fill"
        case "gear": return "shoeprints.fill"
        case "progress": return "chart.xyaxis.line"
        default: return "figure.run.circle.fill"
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "safety": return .red
        case "recovery": return .blue
        case "gear": return .orange
        case "progress": return .purple
        default: return .green
        }
    }
}
