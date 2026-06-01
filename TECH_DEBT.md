# Technical Debt & SwiftLint Warnings — TezDav

В данном документе перечислены все зафиксированные предупреждения статического анализатора кода SwiftLint в проекте TezDav по состоянию на 31 мая 2026 года.

## Summary

* **Ошибки (Errors)**: 0 (Полное соответствие release-требованиям)
* **Предупреждения (Warnings)**: 172
* **Основные категории**:
  1. `File Length` — превышение лимита в 500 строк на файл.
  2. `Function Body Length` — превышение лимита в 60 строк на тело функции.
  3. `Function Parameter Count` — функции с более чем 5 входными параметрами.
  4. `Todo` — оставшиеся комментарии TODO.
  5. `Blanket Disable Command` — локальное отключение правил сложности.

---

## Подробный список предупреждений

### 1. Превышение длины файлов (File Length > 500 строк)

* [ActivityDetailView.swift](file:///Users/hafizov/Dav.TJ/TezDav/Dashboard/ActivityDetailView.swift) (2891 строк) — содержит всю логику детального отображения беговых и велосипедных показателей, графики пульса, каденса, карту, раскладку сплитов и секцию ИИ-анализа. Рекомендуется выделить карту и таблицы сплитов в отдельные SwiftUI-компоненты.
* [FormView.swift](file:///Users/hafizov/Dav.TJ/TezDav/Dashboard/FormView.swift) (1389 строк) — содержит графики спортивной формы (PMC) и историю Readiness. Рекомендуется разделить логику вью-модели и построения графиков Charts.
* [HealthKitManager.swift](file:///Users/hafizov/Dav.TJ/TezDav/TrainingMetrics/HealthKitManager.swift) (577 строк) — интеграционный менеджер данных Apple Health.

### 2. Длина тела функций (Function Body Length > 60 строк)

* **FitParser.swift**:
  * `parse(url:)` (210 строк) — процедура разбора бинарного формата FIT. Требует рефакторинга на вспомогательные функции для чтения каждого сообщения Session/Record.
* **GpxParser.swift**:
  * `parser(_:didStartElement:...)` (143 строки) — SAX XML парсер треков GPX.
* **ExportManager.swift**:
  * `exportToJSONBackup(...)` (94 строки) — сериализация базы данных SwiftData в резервный JSON-файл.
* **NotificationManager.swift**:
  * `checkAndNotifyNewRecords(...)` (82 строки) — проверка обновления личных рекордов по всем типам активностей и отправка локальных PUSH-уведомлений.
* **HealthKitManager.swift**:
  * `calculateDetailedReadiness(...)` (82 строки) — расчет баллов готовности на основе HRV, глубокого сна и TSB.
  * `fetchReadinessHistory(...)` (71 строки) — симуляция и историческая загрузка дней.
* **SyncService.swift**:
  * `checkAndNotifyNewRecords(...)` (61 строка), `parseAndImport(...)` (63 строки), `syncAll(...)` (72 строки).

### 3. Количество параметров функций (Function Parameter Count > 5)

* **HealthKitManager.swift**:
  * `writeWorkout(stravaId:sportType:startDate:duration:distanceMeters:avgHeartRate:)` — 6 параметров. Рекомендуется объединить в структуру `WorkoutSyncPayload`.
  * `calculateDetailedReadiness(hrvToday:hrvBaseline:sleepTotalHours:sleepDeepHours:tsb:daysSinceLastHardWorkout:)` — 6 параметров. Рекомендуется передавать вью-модель или структуру состояния.

### 4. Оставшиеся TODO комментарии

* `StoryFeedDashboardView.swift:110:36` — `// TODO: Get from HealthKit`
* `ActivityCardView.swift:190:12` — `// TODO: Integrate with AI Coach for feedback`

---

## План устранения (Refactoring Roadmap)

1. **Компонентизация UI**: Выделить независимые подэкраны (сплиты, графики) из `ActivityDetailView` в отдельные файлы в папке `Components/`.
2. **Очистка парсеров**: Делегировать разбор записей в `FitParser` и `GpxParser` вспомогательным фабрикам/классам.
3. **Модели параметров**: Внедрить DTO-структуры для уменьшения числа параметров интеграционных методов.
