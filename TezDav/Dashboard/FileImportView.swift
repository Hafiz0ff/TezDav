import SwiftUI
import SwiftData

struct FileImportView: View {
    let fileURLs: [URL]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var existingActivities: [Activity]
    
    @State private var parsedItems: [ImportedCandidate] = []
    @State private var isParsing = true
    @State private var currentParsingIndex = 0
    @State private var errorMessage: String? = nil
    
    struct ImportedCandidate: Identifiable {
        let id = UUID()
        let url: URL
        let activity: Activity
        let samples: [ActivityStreamSample]
        var isDuplicate: Bool
        var duplicateActivityName: String?
        var status: ImportStatus = .pending
        
        enum ImportStatus: Equatable {
            case pending
            case success
            case skipped
            case failed(String)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isParsing {
                    parsingProgressView
                } else {
                    importSummaryView
                }
            }
            .navigationTitle("Импорт файлов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        HapticManager.trigger(.light)
                        dismiss()
                    }
                }
                
                if !isParsing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") {
                            HapticManager.success()
                            saveImportedActivities()
                            dismiss()
                        }
                        .font(.headline)
                    }
                }
            }
            .onAppear {
                startAsyncParsing()
            }
        }
    }
    
    // MARK: - Parsing Progress View
    
    private var parsingProgressView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Обработка файлов...")
                .font(.headline)
            
            if fileURLs.count > 0 {
                let currentFileName = fileURLs[min(currentParsingIndex, fileURLs.count - 1)].lastPathComponent
                Text("Парсинг: \(currentFileName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ProgressView(value: Double(currentParsingIndex), total: Double(fileURLs.count))
                    .padding(.horizontal, 32)
            }
        }
    }
    
    // MARK: - Import Summary View
    
    private var importSummaryView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if parsedItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "xmark.bin.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.red)
                            Text("Нет файлов для импорта")
                                .font(.headline)
                            Text("Выбранные файлы не содержат корректных GPS-треков или повреждены.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .padding()
                    } else {
                        ForEach($parsedItems) { $item in
                            importedCandidateCard(item: $item)
                        }
                    }
                }
                .padding()
            }
            
            if !parsedItems.isEmpty {
                VStack(spacing: 12) {
                    Text("Выберите действия для дубликатов и нажмите Готово для сохранения в SwiftData.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }
                .background(.thinMaterial)
            }
        }
    }
    
    private func importedCandidateCard(item: Binding<ImportedCandidate>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.wrappedValue.activity.sportType == "Ride" ? "bicycle" : "figure.run")
                    .font(.title2)
                    .foregroundStyle(item.wrappedValue.activity.sportType == "Ride" ? Color.green : Color.blue)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.wrappedValue.activity.name)
                        .font(.headline)
                    Text(item.wrappedValue.url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.1f км", item.wrappedValue.activity.distanceMeters / 1000.0))
                    .font(.subheadline.weight(.semibold))
            }
            
            HStack {
                Text("Дата: \(item.wrappedValue.activity.startDate.formatted(date: .abbreviated, time: .shortened))")
                Spacer()
                Text("Время: \(formattedDuration(item.wrappedValue.activity.movingTime))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if item.wrappedValue.isDuplicate {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Обнаружен дубликат!")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    
                    if let dupName = item.wrappedValue.duplicateActivityName {
                        Text("Уже есть тренировка: \(dupName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            HapticManager.trigger(.light)
                            item.wrappedValue.status = .skipped
                        } label: {
                            Text("Пропустить")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(item.wrappedValue.status == .skipped ? Color.orange : Color.gray.opacity(0.1))
                                .foregroundColor(item.wrappedValue.status == .skipped ? .white : .primary)
                                .cornerRadius(8)
                        }
                        
                        Button {
                            HapticManager.trigger(.light)
                            item.wrappedValue.status = .success
                        } label: {
                            Text("Импортировать копию")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(item.wrappedValue.status == .success ? Color.blue : Color.gray.opacity(0.1))
                                .foregroundColor(item.wrappedValue.status == .success ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Core Calculations & Parser Threading
    
    private func startAsyncParsing() {
        Task {
            var items: [ImportedCandidate] = []
            
            for (index, url) in fileURLs.enumerated() {
                await MainActor.run {
                    self.currentParsingIndex = index
                }
                
                // Perform parsing on background thread
                do {
                    let parsed: (activity: Activity, samples: [ActivityStreamSample])
                    
                    if url.pathExtension.lowercased() == "gpx" {
                        parsed = try GpxParser.parse(url: url)
                    } else if url.pathExtension.lowercased() == "fit" {
                        parsed = try FitParser.parse(url: url)
                    } else {
                        continue
                    }
                    
                    // Check duplicate
                    let isDup = checkIsDuplicate(parsed.activity)
                    let duplicateName = isDup.isDuplicate ? isDup.name : nil
                    
                    let candidate = ImportedCandidate(
                        url: url,
                        activity: parsed.activity,
                        samples: parsed.samples,
                        isDuplicate: isDup.isDuplicate,
                        duplicateActivityName: duplicateName,
                        status: isDup.isDuplicate ? .skipped : .success
                    )
                    
                    items.append(candidate)
                } catch {
                    print("Background parsing error for \(url.lastPathComponent): \(error)")
                }
            }
            
            await MainActor.run {
                self.parsedItems = items
                self.isParsing = false
            }
        }
    }
    
    private func checkIsDuplicate(_ act: Activity) -> (isDuplicate: Bool, name: String?) {
        let match = existingActivities.first { existing in
            let dateDiff = abs(existing.startDate.timeIntervalSince1970 - act.startDate.timeIntervalSince1970)
            let distDiff = abs(existing.distanceMeters - act.distanceMeters)
            // Duplicate thresholds: within 5 seconds start time and 15 meters distance
            return dateDiff < 5.0 && distDiff < 15.0
        }
        return (match != nil, match?.name)
    }
    
    private func saveImportedActivities() {
        for item in parsedItems {
            if case .success = item.status {
                // Insert activity
                modelContext.insert(item.activity)
                
                // Insert linked samples
                for sample in item.samples {
                    modelContext.insert(sample)
                }
                
                // Run personal records scan immediately for this workout
                PersonalRecordCalculator.calculateAndSetRecords(for: item.activity, samples: item.samples)
            }
        }
        
        try? modelContext.save()
        
        // Triggers full PMC and notification updates instantly reflecting new load values
        Task {
            let descriptor = FetchDescriptor<UserSettings>()
            if let settings = try? modelContext.fetch(descriptor).first {
                await TrainingLoadCalculator.recalculateAllActivities(context: modelContext, settings: settings)
            }
        }
    }
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
