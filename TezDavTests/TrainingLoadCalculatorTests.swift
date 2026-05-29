import XCTest
import SwiftData
@testable import TezDav

final class TrainingLoadCalculatorTests: XCTestCase {
    func testTRIMPUsesHeartRateReserve() {
        let value = TrainingLoadCalculator.trimp(
            duration: 3600,
            averageHeartRate: 150,
            restingHeartRate: 60,
            maxHeartRate: 190
        )

        XCTAssertEqual(value, 253.4, accuracy: 0.5)
    }

    func testActivityLoadFallsBackWhenHeartRateIsMissing() {
        let input = ActivityMetricInput(
            date: Date(timeIntervalSince1970: 0),
            duration: 3600,
            distanceMeters: 10_000,
            averageHeartRate: nil,
            averagePower: nil,
            sportType: "Run"
        )

        XCTAssertEqual(TrainingLoadCalculator.activityLoad(input), 155, accuracy: 0.01)
    }

    func testPerformanceManagementCalculatesCTLATLAndTSB() {
        let points = TrainingLoadCalculator.performanceManagement(loads: [
            (Date(timeIntervalSince1970: 0), 100),
            (Date(timeIntervalSince1970: 86_400), 50)
        ])

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].ctl, 2.38, accuracy: 0.01)
        XCTAssertEqual(points[0].atl, 14.29, accuracy: 0.01)
        XCTAssertEqual(points[0].tsb, -11.90, accuracy: 0.01)
        XCTAssertEqual(points[1].ctl, 3.51, accuracy: 0.01)
        XCTAssertEqual(points[1].atl, 19.39, accuracy: 0.01)
        XCTAssertEqual(points[1].tsb, -15.88, accuracy: 0.01)
    }

    func testPersonalRecordCalculatorRunningBestTime() {
        let samples = [
            ActivityStreamSample(activityId: 1, offsetSeconds: 0, distanceMeters: 0.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 10, distanceMeters: 100.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 20, distanceMeters: 250.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 30, distanceMeters: 300.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 40, distanceMeters: 450.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 50, distanceMeters: 500.0)
        ]
        
        // Find best time to cover 200m
        let time = PersonalRecordCalculator.bestTime(for: 200.0, in: samples)
        XCTAssertEqual(time, 20.0)
    }

    func testPersonalRecordCalculatorPeakPower() {
        let samples = [
            ActivityStreamSample(activityId: 1, offsetSeconds: 0, distanceMeters: 0.0, power: 100.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 1, distanceMeters: 10.0, power: 200.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 2, distanceMeters: 20.0, power: 300.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 3, distanceMeters: 30.0, power: 150.0),
            ActivityStreamSample(activityId: 1, offsetSeconds: 4, distanceMeters: 40.0, power: 100.0)
        ]
        
        // Find peak power for 2 seconds (3 samples window)
        let peak = PersonalRecordCalculator.peakPower(for: 2, in: samples)
        XCTAssertNotNil(peak)
        XCTAssertEqual(peak!, 216.67, accuracy: 0.1)
    }

    func testUserSettingsMaxHeartRateAndZones() {
        // Test automatic Max HR based on age
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -30, to: .now)! // 30 years old
        
        let settings = UserSettings(
            maxHeartRate: 0.0, // trigger age fallback
            birthDate: birthDate,
            isHeartRateZonesAutomatic: true
        )
        
        // 220 - 30 = 190 Max HR
        XCTAssertEqual(settings.effectiveMaxHeartRate, 190.0)
        
        // Friel zones based on Max HR
        let zones = settings.effectiveHeartRateZones(maxHR: 190.0)
        XCTAssertEqual(zones[0], 123.5)
        XCTAssertEqual(zones[1], 142.5)
        XCTAssertEqual(zones[2], 161.5)
        XCTAssertEqual(zones[3], 174.8, accuracy: 0.1)
    }

    @MainActor
    func testHealthKitRecoveryScoreSDNNEquation() {
        // High readiness: Today HRV = 65, Baseline = 50, Sleep = 8.0, RHR = 55, TSB = 10 (Fresh) -> expect high score (around 99-100)
        let highReadiness = HealthKitManager.shared.calculateRecoveryScore(
            hrvToday: 65.0,
            hrvBaseline: 50.0,
            sleepHours: 8.0,
            restingHR: 55.0,
            tsb: 10.0
        )
        XCTAssertGreaterThanOrEqual(highReadiness, 90)
        
        // Moderate recovery: Today HRV = 35, Baseline = 50, Sleep = 5.0, RHR = 70, TSB = -25 (Fatigued) -> expect lower score
        let moderateRecovery = HealthKitManager.shared.calculateRecoveryScore(
            hrvToday: 35.0,
            hrvBaseline: 50.0,
            sleepHours: 5.0,
            restingHR: 70.0,
            tsb: -25.0
        )
        XCTAssertLessThan(moderateRecovery, 65)
    }
    
    func testIntervalDetectionWithMovingAverage() {
        // Build a simulated stream of a 5x intervals running session:
        var samples: [ActivityStreamSample] = []
        var offset = 0
        var totalDist = 0.0
        
        // 1. Warmup (30 samples)
        for _ in 0..<30 {
            totalDist += 2.5
            samples.append(ActivityStreamSample(activityId: 100, offsetSeconds: offset, distanceMeters: totalDist, speed: 2.5))
            offset += 1
        }
        
        // 2. Repeats
        for _ in 0..<5 {
            // Work segment (40 seconds)
            for _ in 0..<40 {
                totalDist += 5.0
                samples.append(ActivityStreamSample(activityId: 100, offsetSeconds: offset, distanceMeters: totalDist, speed: 5.0))
                offset += 1
            }
            // Recovery segment (30 seconds)
            for _ in 0..<30 {
                totalDist += 2.0
                samples.append(ActivityStreamSample(activityId: 100, offsetSeconds: offset, distanceMeters: totalDist, speed: 2.0))
                offset += 1
            }
        }
        
        let avgSpd = totalDist / Double(offset)
        let segments = IntervalDetector.detectIntervals(activityId: 100, averageSpeed: avgSpd, samples: samples)
        
        XCTAssertGreaterThanOrEqual(segments.count, 5)
        let workReps = segments.filter { $0.type == "work" }
        XCTAssertEqual(workReps.count, 5)
        XCTAssertGreaterThan(workReps[0].averageSpeed, avgSpd)
    }
    
    @MainActor
    func testTrainingPlanCyclicGeneration() {
        let container = try! ModelContainer(for: TrainingWeek.self)
        let context = container.mainContext
        
        let raceDate = Date().addingTimeInterval(86400 * 7 * 10)
        TrainingPlanner.generatePlan(
            raceDate: raceDate,
            currentRunningVolumeMeters: 40000.0,
            currentCyclingHours: 4.0,
            in: context
        )
        
        let descriptor = FetchDescriptor<TrainingWeek>(sortBy: [.init(\.startDate, order: .forward)])
        let weeks = (try? context.fetch(descriptor)) ?? []
        
        XCTAssertEqual(weeks.count, 11)
        XCTAssertEqual(weeks[10].typeString, "Подводящая (тейпер)")
        XCTAssertEqual(weeks[9].typeString, "Подводящая")
        XCTAssertEqual(weeks[0].typeString, "Базовая")
    }
    
    func testGPXExportStructureConformity() {
        let activity = Activity(
            stravaId: 999,
            sportType: "Run",
            name: "Интервалы 5x1k",
            startDate: Date(timeIntervalSince1970: 1770000000),
            distanceMeters: 5000,
            movingTime: 1200,
            elapsedTime: 1200,
            elevationGain: 10,
            trimp: 50,
            trainingLoad: 60
        )
        
        let samples = [
            ActivityStreamSample(activityId: 999, offsetSeconds: 0, distanceMeters: 0.0, latitude: 38.56, longitude: 68.82, heartRate: 140.0, cadence: 80.0, altitude: 800.0),
            ActivityStreamSample(activityId: 999, offsetSeconds: 10, distanceMeters: 50.0, latitude: 38.57, longitude: 68.83, heartRate: 150.0, cadence: 85.0, altitude: 802.0)
        ]
        
        let gpx = ExportManager.exportToGPX(activity: activity, samples: samples)
        
        XCTAssertTrue(gpx.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(gpx.contains("<gpx creator=\"TezDav\" version=\"1.1\""))
        XCTAssertTrue(gpx.contains("<name>Интервалы 5x1k</name>"))
        XCTAssertTrue(gpx.contains("<trkpt lat=\"38.56\" lon=\"68.82\">"))
        XCTAssertTrue(gpx.contains("<gpxtpx:hr>140</gpxtpx:hr>"))
        XCTAssertTrue(gpx.contains("<gpxtpx:cad>80</gpxtpx:cad>"))
        XCTAssertTrue(gpx.contains("</gpx>"))
    }
    
    func testGPXParserDecodingPrecision() {
        let gpxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx creator="TezDav" version="1.1">
          <trk>
            <name>Test Run GPX</name>
            <type>Run</type>
            <trkseg>
              <trkpt lat="38.56" lon="68.82">
                <ele>800.0</ele>
                <time>2026-05-29T10:00:00Z</time>
                <extensions>
                  <gpxtpx:TrackPointExtension>
                    <gpxtpx:hr>140</gpxtpx:hr>
                    <gpxtpx:cad>80</gpxtpx:cad>
                  </gpxtpx:TrackPointExtension>
                </extensions>
              </trkpt>
              <trkpt lat="38.57" lon="68.83">
                <ele>802.0</ele>
                <time>2026-05-29T10:00:10Z</time>
                <extensions>
                  <gpxtpx:TrackPointExtension>
                    <gpxtpx:hr>150</gpxtpx:hr>
                    <gpxtpx:cad>85</gpxtpx:cad>
                  </gpxtpx:TrackPointExtension>
                </extensions>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_activity.gpx")
        try! gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        let parsed = try! GpxParser.parse(url: fileURL)
        
        XCTAssertEqual(parsed.activity.name, "Test Run GPX")
        XCTAssertEqual(parsed.activity.sportType, "Run")
        XCTAssertEqual(parsed.activity.source, "imported")
        XCTAssertEqual(parsed.samples.count, 2)
        XCTAssertEqual(parsed.samples[0].latitude, 38.56)
        XCTAssertEqual(parsed.samples[1].heartRate, 150.0)
    }
}


