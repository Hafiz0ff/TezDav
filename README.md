# TezDav 🏃‍♂️🚴‍♀️

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg?style=flat-square)](https://developer.apple.com/swift/)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=flat-square)](https://developer.apple.com/ios/)
[![watchOS](https://img.shields.io/badge/watchOS-10.0%2B-lightblue.svg?style=flat-square)](https://developer.apple.com/watchos/)
[![SwiftData](https://img.shields.io/badge/SwiftData-Database-purple.svg?style=flat-square)](https://developer.apple.com/xcode/swiftdata/)
[![WidgetKit](https://img.shields.io/badge/WidgetKit-Live_Activities-black.svg?style=flat-square)](https://developer.apple.com/widgets/)

---

## 🇷🇺 Русский раздел (Russian Version)

**TezDav** — это высокотехнологичное мобильное приложение для любителей циклического спорта (бег, велоспорт, триатлон), разработанное для экосистемы Apple (iPhone и Apple Watch). Оно объединяет продвинутую аналитику тренировок, интеллектуальное планирование, построение маршрутов и интерактивное отслеживание нагрузок в реальном времени.

---

### 🌟 Ключевые возможности

#### 1. Интерактивный эфир тренировки (Live Activities & Dynamic Island)
Отображение ключевых параметров физической активности на экране блокировки и в Dynamic Island во время тренировок:
* Живой таймер, дистанция, текущий темп или скорость, а также частота пульса с цветовым кодированием зон интенсивности.
* Адаптивная цветовая гамма, соответствующая выбранному виду спорта (зелёный цвет для бега, синий для велоспорта).
* Поддержка плавной анимации обновления числовых значений.

#### 2. Интерактивный редактор маршрутов (Route Builder)
Продвинутый инструмент для планирования тренировочных трасс:
* Автоматическая привязка к дорожной сети с помощью системных запросов направлений.
* Расчет перепада высот и построение графика рельефа местности в реальном времени.
* Прогнозирование времени прохождения маршрута на основе персонального темпа и функциональных порогов спортсмена.
* Возможность экспортирования в универсальный формат GPX и мгновенной отправки на Apple Watch.

#### 3. Анализ кривой мощности и критической силы (Power Curve & Critical Power)
Глубокая велосипедная аналитика профессионального уровня:
* Расчет максимальной средней мощности (MMP) для скользящих временных окон от 1 секунды до 1 часа.
* Вычисление индивидуального значения критической мощности (Critical Power, CP) и анаэробного энергетического резерва (W') с помощью математической регрессии.
* Автоматическое построение 6 зон мощности Коггана для точечного дозирования интенсивности нагрузок.
* Сравнение текущей сессии с глобальной историей рекордов.

#### 4. Интеграция со службой Apple Здоровье (HealthKit)
Полноценное взаимодействие с системными данными:
* Двусторонняя синхронизация: чтение тренировок из часов и сторонних приложений, запись сессий в HealthKit.
* Анализ сна и утренней вариабельности ритма сердца (HRV) для ежедневного расчета индекса готовности организма к нагрузке (Readiness Score).

#### 5. Интеллектуальный тренировочный планировщик (Training Planner)
Генератор индивидуальных макроциклов подготовки:
* Оценка текущей базовой нагрузки и автоматическое распределение тренировочных недель по типам (базовая, развивающая, восстановительная, подводящая).
* Ежедневные методические рекомендации по проведению интервальных и длительных занятий.

#### 6. Динамическое переключение систем измерения (Метрическая и Имперская)
* Динамическое переформатирование всех величин в приложении (километры/метры/кг $\leftrightarrow$ мили/футы/фунты).
* Автоматический пересчет удельной мощности в Вт/фунт при имперских настройках и перестроение интервальной таблицы сплитов с шагом ровно в 1 милю (вместо 1 км).
* Интерактивное преобразование значений текстовых полей ввода на лету без потери точности хранения данных.

---

### 🛠 Стек технологий и Архитектура

Приложение спроектировано в рамках современной декларативной архитектуры с разделением ответственности и использованием передовых системных инструментов Apple:

* **Пользовательский интерфейс**: SwiftUI с поддержкой динамических шрифтов, тактильного отклика (Haptics) и плавной анимации переходов.
* **База данных**: SwiftData (локальное хранилище данных и настроек на основе CoreData с транзакционной целостностью).
* **Визуализация данных**: Swift Charts (построение интерактивных графиков высоты, кривой мощности и пульсовых зон).
* **Геолокация**: MapKit & CoreLocation (рисование треков, отображение карт, расчет расстояний и геокодирование).
* **Фоновые вычисления**: Accelerate framework (векторизованный метод наименьших квадратов для регрессии Critical Power).
* **Синхронизация с часами**: WatchConnectivity (быстрая передача маршрутов и двусторонняя трансляция спортивных показателей).

---

### 📸 Иллюстрации интерфейса

<table>
  <tr>
    <td width="50%">
      <p align="center"><b>Панель настроек и переключение единиц</b></p>
      <img src="docs/screenshots/settings_metric_toggle.png" alt="Настройки системы измерения" width="100%">
    </td>
    <td width="50%">
      <p align="center"><b>Анализ активности (Имперские единицы)</b></p>
      <img src="docs/screenshots/imperial_activity_details.png" alt="Экран тренировки в милях" width="100%">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <p align="center"><b>Индивидуальная кривая мощности</b></p>
      <img src="docs/screenshots/power_curve_form_tab.png" alt="Кривая мощности" width="100%">
    </td>
    <td width="50%">
      <p align="center"><b>Зоны мощности Коггана на основе CP</b></p>
      <img src="docs/screenshots/critical_power_zones.png" alt="Зоны мощности" width="100%">
    </td>
  </tr>
</table>

<p align="center">
  <b>Сопоставление рекордов мощности тренировки с историей</b><br>
  <img src="docs/screenshots/activity_detail_power_curve.png" alt="Детальная кривая тренировки" width="50%">
</p>

---

## 🇬🇧 English Section

**TezDav** is a high-performance training analytics and navigation mobile application tailored for multi-sport athletes (running, cycling, triathlon) in the Apple ecosystem (iPhone and Apple Watch). It aggregates historical metrics, automates cycle planning, builds custom routes, and presents training workloads dynamically.

---

### 🌟 Key Features

* **Live Activities & Dynamic Island**: Real-time tracking displaying timer, distance, current speed/pace, and heart rate with zone color-coding.
* **Interactive Route Builder**: Tap-to-create routes with automatic road-snapping (MKDirections API), elevation profiles (Open-Elevation API integration), estimated duration modeling, and watch synchronization.
* **Power Curve & Critical Power Solver**: Professional cycling analytics featuring Mean Maximal Power (MMP) windows, hyperbolic regression calculations for Critical Power (CP) and anaerobic capacity (W'), and Coggan's power zones.
* **Apple Health (HealthKit) Integration**: Dual synchronization reading activities, sleep analyses, and Heart Rate Variability (HRV) metrics to evaluate daily Readiness Scores.
* **Structured Training Planner**: Dynamic training schedule generator adapting blocks into recovery, developmental, and tapering cycles based on historical workloads.
* **Unified Imperial/Metric Engine**: Global system conversion instantly formatting inputs, charts, and values. Automatically splits running/cycling intervals into 1-mile laps with pace and elevation gains formatted dynamically (mi, ft, lbs, mph, W/lbs).

---

### 🛠 Technology Stack & Architecture

* **UI Framework**: SwiftUI (declarative interface, custom modifiers, haptic feedbacks, and interactive navigation flows).
* **Local Persistence**: SwiftData (type-safe SQLite model handling and relationships).
* **Data Visualization**: Swift Charts (line graphs, logarithmic coordinate axes, cursors, and shaded area mark representations).
* **Mapping**: MapKit, MapPolyline, and CoreLocation.
* **Computations**: Accelerate framework (used for fast, vectorized regression solvers).
* **Watch Companion Integration**: WatchConnectivity (handling route transfers and live telemetry streams).
