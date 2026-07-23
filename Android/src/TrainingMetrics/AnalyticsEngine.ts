import type { StreamSample } from './ActivityMetricsEngine';

export interface DistanceRecord {
  distanceMeters: number;
  durationSeconds: number | null;
  activityId?: string;
  activityTitle?: string;
  activityDate?: string;
}

export const STANDARD_RUNNING_DISTANCES = [
  { label: '1 км', meters: 1_000 },
  { label: '5 км', meters: 5_000 },
  { label: '10 км', meters: 10_000 },
  { label: 'Полумарафон', meters: 21_097.5 },
  { label: 'Марафон', meters: 42_195 },
] as const;

export class AnalyticsEngine {
  static findBestEffort(samples: StreamSample[], targetMeters: number): number | null {
    if (!Number.isFinite(targetMeters) || targetMeters <= 0) return null;

    const points = samples
      .filter(
        (sample): sample is StreamSample & { distanceMeters: number } =>
          Number.isFinite(sample.offsetSeconds) &&
          sample.offsetSeconds >= 0 &&
          sample.distanceMeters !== undefined &&
          Number.isFinite(sample.distanceMeters) &&
          sample.distanceMeters >= 0,
      )
      .sort((a, b) => a.offsetSeconds - b.offsetSeconds)
      .filter(
        (point, index, all) =>
          index === 0 ||
          (point.offsetSeconds > all[index - 1].offsetSeconds &&
            point.distanceMeters >= all[index - 1].distanceMeters),
      );

    if (points.length < 2) return null;

    let best = Number.POSITIVE_INFINITY;
    let endIndex = 1;
    for (let startIndex = 0; startIndex < points.length - 1; startIndex++) {
      const targetDistance = points[startIndex].distanceMeters + targetMeters;
      endIndex = Math.max(endIndex, startIndex + 1);
      while (endIndex < points.length && points[endIndex].distanceMeters < targetDistance) {
        endIndex++;
      }
      if (endIndex >= points.length) break;

      const end = points[endIndex];
      const previous = points[endIndex - 1];
      if (end.distanceMeters <= previous.distanceMeters) continue;
      const ratio =
        (targetDistance - previous.distanceMeters) /
        (end.distanceMeters - previous.distanceMeters);
      const targetTime =
        previous.offsetSeconds + ratio * (end.offsetSeconds - previous.offsetSeconds);
      const duration = targetTime - points[startIndex].offsetSeconds;
      if (duration > 0) best = Math.min(best, duration);
    }

    return Number.isFinite(best) ? best : null;
  }

  static predictRiegelTime(
    knownDistanceMeters: number,
    knownDurationSeconds: number,
    targetDistanceMeters: number,
  ): number | null {
    if (
      !Number.isFinite(knownDistanceMeters) ||
      !Number.isFinite(knownDurationSeconds) ||
      !Number.isFinite(targetDistanceMeters) ||
      knownDistanceMeters <= 0 ||
      knownDurationSeconds <= 0 ||
      targetDistanceMeters <= 0
    ) {
      return null;
    }
    return knownDurationSeconds * Math.pow(targetDistanceMeters / knownDistanceMeters, 1.06);
  }

  static estimateDanielsVO2Max(distanceMeters: number, durationSeconds: number): number | null {
    if (
      !Number.isFinite(distanceMeters) ||
      !Number.isFinite(durationSeconds) ||
      distanceMeters <= 0 ||
      durationSeconds <= 0
    ) {
      return null;
    }

    const durationMinutes = durationSeconds / 60;
    const velocity = distanceMeters / durationMinutes;
    const oxygenCost = -4.6 + 0.182258 * velocity + 0.000104 * velocity * velocity;
    const sustainableFraction =
      0.8 +
      0.1894393 * Math.exp(-0.012778 * durationMinutes) +
      0.2989558 * Math.exp(-0.1932605 * durationMinutes);
    const estimate = oxygenCost / sustainableFraction;
    return Number.isFinite(estimate) && estimate > 0 ? estimate : null;
  }
}
