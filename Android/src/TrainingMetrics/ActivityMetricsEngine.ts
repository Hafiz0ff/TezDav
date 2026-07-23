export interface StreamSample {
  offsetSeconds: number;
  distanceMeters?: number;
  heartRate?: number;
  power?: number;
  elevation?: number;
}

export interface KilometerSplit {
  index: number; // 1, 2, 3...
  pace: number; // seconds per km
  avgHeartRate?: number;
  elevationChange: number;
}

export class ActivityMetricsEngine {
  /**
   * Разделяет поток на километровые отрезки (сплиты)
   */
  static calculateKilometerSplits(samples: StreamSample[]): KilometerSplit[] {
    const validSamples = samples
      .filter(
        (sample) =>
          Number.isFinite(sample.offsetSeconds) &&
          Number.isFinite(sample.distanceMeters),
      )
      .sort((a, b) => a.offsetSeconds - b.offsetSeconds);
    if (validSamples.length < 2) return [];

    const splits: KilometerSplit[] = [];
    const first = validSamples[0];
    let splitStartDistance = first.distanceMeters!;
    let splitStartTime = first.offsetSeconds;
    let splitStartElevation = first.elevation;
    let targetDistance = (Math.floor(splitStartDistance / 1000) + 1) * 1000;

    for (let index = 1; index < validSamples.length; index++) {
      const previous = validSamples[index - 1];
      const current = validSamples[index];
      const previousDistance = previous.distanceMeters!;
      const currentDistance = current.distanceMeters!;

      if (
        currentDistance <= previousDistance ||
        current.offsetSeconds <= previous.offsetSeconds
      ) {
        continue;
      }

      while (targetDistance <= currentDistance) {
        const ratio =
          (targetDistance - previousDistance) /
          (currentDistance - previousDistance);
        const endTime =
          previous.offsetSeconds +
          ratio * (current.offsetSeconds - previous.offsetSeconds);
        const endElevation = this.interpolateOptional(
          previous.elevation,
          current.elevation,
          ratio,
        );
        const splitDistance = targetDistance - splitStartDistance;

        if (splitDistance >= 50 && endTime > splitStartTime) {
          splits.push({
            index: splits.length + 1,
            pace: (endTime - splitStartTime) / (splitDistance / 1000),
            avgHeartRate: this.averageHeartRate(
              validSamples,
              splitStartDistance,
              targetDistance,
            ),
            elevationChange:
              endElevation !== undefined && splitStartElevation !== undefined
                ? endElevation - splitStartElevation
                : 0,
          });
        }

        splitStartDistance = targetDistance;
        splitStartTime = endTime;
        splitStartElevation = endElevation;
        targetDistance += 1000;
      }
    }

    const last = validSamples[validSamples.length - 1];
    const finalDistance = last.distanceMeters! - splitStartDistance;
    if (finalDistance >= 50 && last.offsetSeconds > splitStartTime) {
      splits.push({
        index: splits.length + 1,
        pace: (last.offsetSeconds - splitStartTime) / (finalDistance / 1000),
        avgHeartRate: this.averageHeartRate(
          validSamples,
          splitStartDistance,
          last.distanceMeters!,
        ),
        elevationChange:
          last.elevation !== undefined && splitStartElevation !== undefined
            ? last.elevation - splitStartElevation
            : 0,
      });
    }

    return splits;
  }

  /**
   * Рассчитывает время, проведенное в каждой пульсовой зоне.
   * Возвращает массив из 5 чисел (секунды в каждой зоне: Z1, Z2, Z3, Z4, Z5)
   */
  static calculateHeartRateZoneTimes(samples: StreamSample[], maxHR: number, restingHR: number): number[] {
    const zoneTimes = [0, 0, 0, 0, 0];
    if (!samples || samples.length < 2) return zoneTimes;

    // Простые пороги по умолчанию (как в Apple Health / Garmin)
    const z1Max = maxHR * 0.6;
    const z2Max = maxHR * 0.7;
    const z3Max = maxHR * 0.8;
    const z4Max = maxHR * 0.9;

    const sortedSamples = samples
      .filter((sample) => Number.isFinite(sample.offsetSeconds))
      .sort((a, b) => a.offsetSeconds - b.offsetSeconds);

    for (let i = 1; i < sortedSamples.length; i++) {
      const prev = sortedSamples[i - 1];
      const curr = sortedSamples[i];
      const duration = curr.offsetSeconds - prev.offsetSeconds;

      if (duration > 0 && curr.heartRate !== undefined && Number.isFinite(curr.heartRate)) {
        const hr = curr.heartRate;
        if (hr > z4Max) {
          zoneTimes[4] += duration;
        } else if (hr > z3Max) {
          zoneTimes[3] += duration;
        } else if (hr > z2Max) {
          zoneTimes[2] += duration;
        } else if (hr > z1Max) {
          zoneTimes[1] += duration;
        } else if (hr >= restingHR) {
          zoneTimes[0] += duration;
        }
      }
    }

    return zoneTimes;
  }

  /**
   * Нормализованная мощность (NP) по алгоритму Коггана.
   * Требуется поток мощности (Вт).
   */
  static calculateNormalizedPower(powerStream: number[]): number | null {
    if (
      !powerStream ||
      powerStream.length < 30 ||
      powerStream.some((power) => !Number.isFinite(power) || power < 0)
    ) {
      return null;
    }

    const powersOfRollingAvgs: number[] = [];
    let rollingSum = powerStream.slice(0, 30).reduce((sum, power) => sum + power, 0);

    // Скользящее среднее за 30 секунд
    for (let i = 29; i < powerStream.length; i++) {
      if (i > 29) {
        rollingSum += powerStream[i] - powerStream[i - 30];
      }
      const avg = rollingSum / 30.0;
      powersOfRollingAvgs.push(Math.pow(avg, 4));
    }

    if (powersOfRollingAvgs.length === 0) return null;

    let meanOfPowers = 0;
    for (const val of powersOfRollingAvgs) {
      meanOfPowers += val;
    }
    meanOfPowers /= powersOfRollingAvgs.length;

    return Math.pow(meanOfPowers, 0.25);
  }

  private static interpolateOptional(
    start: number | undefined,
    end: number | undefined,
    ratio: number,
  ): number | undefined {
    if (start === undefined || end === undefined) return undefined;
    return start + ratio * (end - start);
  }

  private static averageHeartRate(
    samples: StreamSample[],
    startDistance: number,
    endDistance: number,
  ): number | undefined {
    const values = samples
      .filter(
        (sample) =>
          sample.distanceMeters !== undefined &&
          sample.distanceMeters >= startDistance &&
          sample.distanceMeters <= endDistance &&
          sample.heartRate !== undefined &&
          Number.isFinite(sample.heartRate),
      )
      .map((sample) => sample.heartRate!);

    if (values.length === 0) return undefined;
    return values.reduce((sum, value) => sum + value, 0) / values.length;
  }
}
