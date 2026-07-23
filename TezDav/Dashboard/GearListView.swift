import SwiftUI
import SwiftData

struct GearListView: View {
    @Query(sort: \GearItem.startDate, order: .reverse) private var gears: [GearItem]
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingAddSheet = false
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        let activeGears = gears.filter { $0.isActive }
        let retiredGears = gears.filter { !$0.isActive }
        
        NavigationStack {
            List {
                if gears.isEmpty {
                    ContentUnavailableView(
                        isRussian ? "Экипировки нет" : "No Gear Tracked",
                        systemImage: "shoeprints.fill",
                        description: Text(isRussian ? "Добавьте кроссовки или детали велосипеда, чтобы следить за их износом." : "Add running shoes or cycling components to track their lifespan.")
                    )
                } else {
                    if !activeGears.isEmpty {
                        Section(isRussian ? "Активное снаряжение" : "Active Gear") {
                            ForEach(activeGears) { gear in
                                NavigationLink(destination: GearDetailView(gear: gear, activities: activities)) {
                                    GearRowView(gear: gear)
                                }
                            }
                        }
                    }
                    
                    if !retiredGears.isEmpty {
                        Section(isRussian ? "Архив экипировки" : "Retired Gear") {
                            ForEach(retiredGears) { gear in
                                NavigationLink(destination: GearDetailView(gear: gear, activities: activities)) {
                                    GearRowView(gear: gear)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isRussian ? "Моя экипировка" : "Gear & Equipment")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.trigger(.light)
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddGearView()
            }
        }
    }
}

// MARK: - Row View
struct GearRowView: View {
    let gear: GearItem
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        let pct = gear.maxDistanceKm > 0 ? (gear.currentDistanceKm / gear.maxDistanceKm) : 0.0
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: gear.sportType == "Ride" ? "bicycle" : "figure.run")
                    .font(.title3)
                    .foregroundStyle(gear.sportType == "Ride" ? .green : .blue)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(gear.name)
                        .font(.headline)
                    if let brand = gear.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f / %.0f км", gear.currentDistanceKm, gear.maxDistanceKm))
                        .font(.subheadline.bold())
                    Text(String(format: "%.0f%%", min(1.0, pct) * 100))
                        .font(.caption)
                        .foregroundStyle(wearColor(pct))
                        .fontWeight(.semibold)
                }
            }
            
            // Wear indicator progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(wearColor(pct).gradient)
                        .frame(width: max(0, min(geo.size.width * CGFloat(pct), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private func wearColor(_ pct: Double) -> Color {
        if pct < 0.6 { return .green }
        if pct < 0.85 { return .yellow }
        return .red
    }
}

// MARK: - Gear Detail View
struct GearDetailView: View {
    let gear: GearItem
    let activities: [Activity]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        let gearActivities = activities.filter { $0.gearItem?.id == gear.id }
        let topActivities = Array(gearActivities.sorted { $0.distanceMeters > $1.distanceMeters }.prefix(5))
        
        List {
            Section(isRussian ? "Основная информация" : "Main Telemetry") {
                LabeledContent(isRussian ? "Название" : "Name", value: gear.name)
                if let brand = gear.brand {
                    LabeledContent(isRussian ? "Бренд" : "Brand", value: brand)
                }
                LabeledContent(isRussian ? "Тип спорта" : "Sport Type", value: gear.sportType == "Ride" ? (isRussian ? "Велосипед" : "Ride") : (isRussian ? "Бег" : "Run"))
                LabeledContent(isRussian ? "Тип детали" : "Gear Type", value: gear.gearType)
                LabeledContent(isRussian ? "Начало использования" : "Start Date", value: gear.startDate.formatted(date: .long, time: .omitted))
                LabeledContent(isRussian ? "Текущий износ" : "Current Mileage", value: String(format: "%.1f км / %.0f км", gear.currentDistanceKm, gear.maxDistanceKm))
                
                Toggle(isRussian ? "Активно" : "Is Active", isOn: Binding(
                    get: { gear.isActive },
                    set: { val in
                        gear.isActive = val
                        try? modelContext.save()
                    }
                ))
            }
            
            Section(isRussian ? "Статистика использования" : "Usage Stats") {
                LabeledContent(isRussian ? "Всего тренировок" : "Total Workouts", value: "\(gearActivities.count)")
                if gearActivities.count > 0 {
                    let totalMeters = gearActivities.reduce(0.0) { $0 + $1.distanceMeters }
                    let avgDist = (totalMeters / Double(gearActivities.count)) / 1000.0
                    LabeledContent(isRussian ? "Средняя дистанция" : "Average Distance", value: String(format: "%.1f км", avgDist))
                }
            }
            
            if !topActivities.isEmpty {
                Section(isRussian ? "Топ 5 длинных тренировок" : "Top 5 Longest Workouts") {
                    ForEach(topActivities) { activity in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(activity.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.1f км", activity.distanceMeters / 1000.0))
                                .font(.subheadline.weight(.bold))
                        }
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    HapticManager.trigger(.heavy)
                    modelContext.delete(gear)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text(isRussian ? "Удалить экипировку" : "Delete Gear")
                        .frame(maxWidth: .infinity)
                        .alignmentGuide(.leading) { _ in 0 }
                }
            }
        }
        .navigationTitle(gear.name)
    }
}

// MARK: - Add Gear Sheet
struct AddGearView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var brand = ""
    @State private var sportType = "Run"
    @State private var gearType = "shoes"
    @State private var startDate = Date()
    @State private var startingDistance = ""
    @State private var maxDistance = "700"
    @State private var stravaGearId = ""
    @State private var isDefault = false
    
    var body: some View {
        let isRussian = AppLanguage.isRussian
        
        NavigationStack {
            Form {
                Section(isRussian ? "Параметры экипировки" : "Gear Specifications") {
                    TextField(isRussian ? "Название (например, Pegasus 39)" : "Name (e.g. Pegasus 39)", text: $name)
                    TextField(isRussian ? "Бренд (Nike, Shimano)" : "Brand (Nike, Shimano)", text: $brand)
                    
                    Picker(isRussian ? "Вид спорта" : "Sport", selection: $sportType) {
                        Text(isRussian ? "Бег" : "Run").tag("Run")
                        Text(isRussian ? "Велосипед" : "Ride").tag("Ride")
                    }
                    .pickerStyle(.segmented)
                    
                    Picker(isRussian ? "Тип экипировки" : "Gear Category", selection: $gearType) {
                        if sportType == "Run" {
                            Text(isRussian ? "Кроссовки" : "Shoes").tag("shoes")
                        } else {
                            Text(isRussian ? "Велосипед" : "Bike").tag("bike")
                            Text(isRussian ? "Цепь" : "Chain").tag("chain")
                            Text(isRussian ? "Колодки" : "Pads").tag("pads")
                        }
                    }
                    .onChange(of: sportType) { _, newValue in
                        gearType = newValue == "Run" ? "shoes" : "bike"
                    }
                }
                
                Section(isRussian ? "Ресурс и Износ" : "Lifespan Details") {
                    DatePicker(isRussian ? "Дата начала" : "Purchase/Start Date", selection: $startDate, displayedComponents: .date)
                    
                    HStack {
                        Text(isRussian ? "Начальный пробег (км)" : "Starting Mileage (km)")
                        Spacer()
                        TextField("0", text: $startingDistance)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text(isRussian ? "Лимит ресурса (км)" : "Maximum Lifespan (km)")
                        Spacer()
                        TextField("700", text: $maxDistance)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    TextField(isRussian ? "Идентификатор снаряжения Strava (необязательно)" : "Strava Gear ID (optional)", text: $stravaGearId)
                    
                    Toggle(isRussian ? "Снаряжение по умолчанию" : "Set as Default Sport Gear", isOn: $isDefault)
                }
            }
            .navigationTitle(isRussian ? "Новое снаряжение" : "Add Equipment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRussian ? "Отмена" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isRussian ? "Создать" : "Save") {
                        saveGear()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveGear() {
        let doubleMax = Double(maxDistance) ?? 700.0
        let doubleStarting = Double(startingDistance) ?? 0.0
        
        let newGear = GearItem(
            name: name,
            sportType: sportType,
            gearType: gearType,
            brand: brand.isEmpty ? nil : brand,
            startDate: startDate,
            maxDistanceKm: doubleMax,
            currentDistanceKm: doubleStarting,
            isActive: true,
            stravaGearId: stravaGearId.isEmpty ? nil : stravaGearId
        )
        
        modelContext.insert(newGear)
        
        if isDefault {
            // Unmark other defaults for this sport
            let descriptor = FetchDescriptor<GearItem>()
            if let gears = try? modelContext.fetch(descriptor) {
                for g in gears {
                    if g.sportType == sportType && g.id != newGear.id {
                        // We will treat default status as the only active gear of that type or handle default mapping
                    }
                }
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
}
