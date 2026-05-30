import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var isConnected: Bool
    @Binding var onboardingCompleted: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 1
    
    // User Profile settings states
    @State private var birthDate = Date().addingTimeInterval(-86400 * 365 * 30) // Default 30 years old
    @State private var hasBirthDate = true
    @State private var maxHRString: String = "0"
    @State private var mainSport: String = "Run"
    @State private var weeklyGoalKm: String = "40"
    @State private var appMode: AppMode = .pro
    @State private var targetWeeklyActiveMinutes: String = "150"
    
    private let config = StravaConfig.fromBundle()
    
    var body: some View {
        ZStack {
            // Sleek premium dark/light harmonious background
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                // Header progress dots
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue.gradient : Color.gray.opacity(0.3).gradient)
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                switch currentStep {
                case 1:
                    welcomeStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 2:
                    stravaStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 3:
                    settingsStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                default:
                    EmptyView()
                }
                
                Spacer()
            }
            .padding()
        }
        .onChange(of: isConnected) { oldValue, newValue in
            // If Strava connects successfully while on step 2, auto-transition to settings step
            if newValue && currentStep == 2 {
                withAnimation(.spring()) {
                    currentStep = 3
                }
            }
        }
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("TezDav")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.blue.gradient)
                
                Text("Локальный разбор тренировок")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
            }
            
            // Premium glassmorphism card visual
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(width: 220, height: 220)
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 10)
                
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .padding(.vertical)
            
            Text("Всё, что спортивные сервисы прячут за платной подпиской, теперь доступно бесплатно и конфиденциально прямо на вашем iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                HapticManager.trigger(.medium)
                withAnimation(.spring()) {
                    currentStep = 2
                }
            } label: {
                Text("Начать")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Strava Connect Step
    
    private var stravaStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange.gradient)
                
                Text("Подключение Strava")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }
            
            Text("Авторизация в Strava позволяет автоматически загружать ваши тренировки, пульсовые данные и статистику. TezDav проанализирует каждый метр вашей активности бесплатно.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 16) {
                Button {
                    HapticManager.trigger(.medium)
                    connectStrava()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Подключить Strava")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    HapticManager.trigger(.light)
                    withAnimation(.spring()) {
                        currentStep = 3
                    }
                } label: {
                    Text("Пропустить")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Settings Step
    
    private var settingsStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Базовые настройки")
                    .font(.title2.weight(.bold))
                Text("Эти данные важны для точного расчета тренировочных зон и баланса формы.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Main Sport selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Основной вид спорта")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Picker("Спорт", selection: $mainSport) {
                        Text("Бег").tag("Run")
                        Text("Велосипед").tag("Ride")
                        Text("Триатлон").tag("Triathlon")
                        Text("Ходьба").tag("Walk")
                        Text("Плавание").tag("Swim")
                    }
                    .pickerStyle(.segmented)
                }
                
                // App Mode selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Режим работы")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Picker("Режим", selection: $appMode) {
                        Text("Любитель (Casual)").tag(AppMode.casual)
                        Text("Спортсмен (Pro)").tag(AppMode.pro)
                    }
                    .pickerStyle(.segmented)
                }
                
                let showProFields = appMode == .pro && mainSport != "Walk" && mainSport != "Swim"
                
                if showProFields {
                    // Birth Date
                    DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                        .font(.subheadline.weight(.semibold))
                    
                    // Max Heart Rate
                    VStack(alignment: .leading, spacing: 6) {
                        let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
                        let autoHR = 220 - age
                        
                        HStack {
                            Text("Максимальный пульс (BPM)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Авто: \(autoHR)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        TextField("Оставьте 0 для авто-расчета", text: $maxHRString)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(8)
                    }
                    
                    // Weekly running distance
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Целевой недельный объём бега (км)")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("Например, 40", text: $weeklyGoalKm)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(8)
                    }
                } else {
                    // Casual / Walk / Swim fields:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Цель активных минут в неделю")
                            .font(.subheadline.weight(.semibold))
                        
                        TextField("Например, 150", text: $targetWeeklyActiveMinutes)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            Button {
                HapticManager.success()
                saveSettingsAndFinish()
            } label: {
                Text("Готово")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Actions
    
    private func connectStrava() {
        do {
            let state = UUID().uuidString
            let authURL = try StravaOAuth.authorizationURL(config: config, state: state)
            UIApplication.shared.open(authURL)
        } catch {
            print("Failed to open Strava Authorization URL: \(error)")
        }
    }
    
    private func saveSettingsAndFinish() {
        let settings = UserSettings.getOrCreate(in: modelContext)
        
        settings.mainSport = mainSport
        settings.appMode = appMode
        
        let showProFields = appMode == .pro && mainSport != "Walk" && mainSport != "Swim"
        
        if showProFields {
            settings.birthDate = birthDate
            let hrInput = Double(maxHRString) ?? 0.0
            if hrInput > 0 {
                settings.maxHeartRate = hrInput
            } else {
                let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
                settings.maxHeartRate = Double(220 - age)
            }
            if let km = Double(weeklyGoalKm) {
                settings.targetWeeklyDistanceMeters = km * 1000.0
            }
        } else {
            settings.maxHeartRate = 190.0
            settings.targetWeeklyActiveMinutes = Double(targetWeeklyActiveMinutes) ?? 150.0
            // If they chose Walk or Swim, automatically force appMode = .casual
            if mainSport == "Walk" || mainSport == "Swim" {
                settings.appMode = .casual
            } else {
                settings.appMode = .casual
            }
        }
        
        try? modelContext.save()
        
        // Trigger initial data load / PMC calculation
        Task {
            await TrainingLoadCalculator.recalculateAllActivities(context: modelContext, settings: settings)
        }
        
        onboardingCompleted = true
    }
}
