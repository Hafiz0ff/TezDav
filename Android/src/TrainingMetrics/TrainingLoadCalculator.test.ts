import { describe, expect, it } from 'vitest';
import { TrainingLoadCalculator } from './TrainingLoadCalculator';

describe('TrainingLoadCalculator', () => {
  it('aggregates activities on the same day', () => {
    const result = TrainingLoadCalculator.calculatePMC([
      { date: new Date(2026, 0, 1, 8), tss: 40 },
      { date: new Date(2026, 0, 1, 18), tss: 60 },
    ]);

    expect(result).toHaveLength(1);
    const expectedCtl = 100 * (1 - Math.exp(-1 / 42));
    const expectedAtl = 100 * (1 - Math.exp(-1 / 7));
    expect(result[0].ctl).toBeCloseTo(expectedCtl, 8);
    expect(result[0].atl).toBeCloseTo(expectedAtl, 8);
  });

  it('inserts zero-load days between activities', () => {
    const result = TrainingLoadCalculator.calculatePMC([
      { date: new Date(2026, 0, 1), tss: 100 },
      { date: new Date(2026, 0, 3), tss: 50 },
    ]);

    expect(result).toHaveLength(3);
    expect(result.map(({ date }) => date.getDate())).toEqual([1, 2, 3]);
    expect(result[1].ctl).toBeLessThan(result[0].ctl);
    expect(result[1].atl).toBeLessThan(result[0].atl);
  });

  it('ignores invalid and negative loads', () => {
    const result = TrainingLoadCalculator.calculatePMC([
      { date: new Date('invalid'), tss: 20 },
      { date: new Date(2026, 0, 1), tss: -10 },
    ]);

    expect(result).toEqual([]);
  });
});
