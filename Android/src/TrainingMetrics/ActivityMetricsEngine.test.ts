import { describe, expect, it } from 'vitest';
import { ActivityMetricsEngine } from './ActivityMetricsEngine';

describe('ActivityMetricsEngine', () => {
  it('interpolates every kilometer across sparse samples', () => {
    const splits = ActivityMetricsEngine.calculateKilometerSplits([
      { offsetSeconds: 0, distanceMeters: 0, heartRate: 120, elevation: 100 },
      { offsetSeconds: 750, distanceMeters: 2500, heartRate: 150, elevation: 125 },
    ]);

    expect(splits).toHaveLength(3);
    expect(splits.map(({ pace }) => pace)).toEqual([300, 300, 300]);
    expect(splits.map(({ index }) => index)).toEqual([1, 2, 3]);
    expect(splits[2].elevationChange).toBeCloseTo(5, 8);
  });

  it('does not lose samples at split boundaries', () => {
    const splits = ActivityMetricsEngine.calculateKilometerSplits([
      { offsetSeconds: 0, distanceMeters: 0 },
      { offsetSeconds: 300, distanceMeters: 1000 },
      { offsetSeconds: 600, distanceMeters: 2000 },
    ]);

    expect(splits).toHaveLength(2);
    expect(splits[0].pace).toBe(300);
    expect(splits[1].pace).toBe(300);
  });

  it('counts heart-rate zone durations from sorted samples', () => {
    const zones = ActivityMetricsEngine.calculateHeartRateZoneTimes(
      [
        { offsetSeconds: 20, heartRate: 181 },
        { offsetSeconds: 0, heartRate: 100 },
        { offsetSeconds: 10, heartRate: 130 },
      ],
      200,
      60,
    );

    expect(zones).toEqual([0, 10, 0, 0, 10]);
  });

  it('calculates normalized power for a constant stream', () => {
    expect(ActivityMetricsEngine.calculateNormalizedPower(Array(60).fill(200))).toBeCloseTo(200, 8);
    expect(ActivityMetricsEngine.calculateNormalizedPower([...
      Array(29).fill(200),
      Number.NaN,
    ])).toBeNull();
  });
});
