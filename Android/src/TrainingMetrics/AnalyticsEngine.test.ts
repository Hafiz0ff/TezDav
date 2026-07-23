import { describe, expect, it } from 'vitest';
import { AnalyticsEngine } from './AnalyticsEngine';

describe('AnalyticsEngine', () => {
  it('finds a best effort and interpolates the target crossing', () => {
    const samples = Array.from({ length: 13 }, (_, index) => ({
      offsetSeconds: index * 60,
      distanceMeters: index * 1_000,
    }));

    expect(AnalyticsEngine.findBestEffort(samples, 5_000)).toBe(300);
    expect(AnalyticsEngine.findBestEffort(samples, 10_500)).toBe(630);
  });

  it('returns null when a distance stream is too short', () => {
    expect(
      AnalyticsEngine.findBestEffort(
        [
          { offsetSeconds: 0, distanceMeters: 0 },
          { offsetSeconds: 60, distanceMeters: 900 },
        ],
        1_000,
      ),
    ).toBeNull();
  });

  it('predicts race time with the Riegel formula', () => {
    expect(AnalyticsEngine.predictRiegelTime(5_000, 1_200, 10_000)).toBeCloseTo(2501.9, 0);
  });

  it('estimates a plausible Daniels value for a 20 minute 5K', () => {
    expect(AnalyticsEngine.estimateDanielsVO2Max(5_000, 1_200)).toBeCloseTo(49.8, 0);
  });
});
