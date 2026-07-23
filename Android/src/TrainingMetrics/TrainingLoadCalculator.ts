export interface DailyMetrics {
  date: Date;
  tss: number;
}

export interface PMCMetrics {
  date: Date;
  ctl: number; // Fitness
  atl: number; // Fatigue
  tsb: number; // Form
}

export class TrainingLoadCalculator {
  private static ctlTimeConstant = 42; // standard 42 days for fitness
  private static atlTimeConstant = 7;  // standard 7 days for fatigue

  /**
   * Calculates the exponentially weighted moving average for CTL/ATL
   */
  static calculatePMC(dailyMetrics: DailyMetrics[]): PMCMetrics[] {
    const validMetrics = dailyMetrics.filter(
      ({ date, tss }) =>
        !Number.isNaN(date.getTime()) && Number.isFinite(tss) && tss >= 0,
    );
    if (validMetrics.length === 0) return [];

    const tssByDay = new Map<string, number>();
    for (const metric of validMetrics) {
      const key = this.localDayKey(metric.date);
      tssByDay.set(key, (tssByDay.get(key) ?? 0) + metric.tss);
    }

    const sortedDates = validMetrics
      .map(({ date }) => this.startOfLocalDay(date))
      .sort((a, b) => a.getTime() - b.getTime());
    const cursor = sortedDates[0];
    const endDate = sortedDates[sortedDates.length - 1];
    let currentCTL = 0;
    let currentATL = 0;
    const ctlDecay = Math.exp(-1 / this.ctlTimeConstant);
    const atlDecay = Math.exp(-1 / this.atlTimeConstant);
    const result: PMCMetrics[] = [];

    while (cursor.getTime() <= endDate.getTime()) {
      const tss = tssByDay.get(this.localDayKey(cursor)) ?? 0;
      currentCTL = tss * (1 - ctlDecay) + currentCTL * ctlDecay;
      currentATL = tss * (1 - atlDecay) + currentATL * atlDecay;

      result.push({
        date: new Date(cursor),
        ctl: currentCTL,
        atl: currentATL,
        tsb: currentCTL - currentATL,
      });
      cursor.setDate(cursor.getDate() + 1);
    }

    return result;
  }

  private static startOfLocalDay(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
  }

  private static localDayKey(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
