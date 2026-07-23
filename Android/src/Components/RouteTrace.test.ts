import { describe, expect, it } from 'vitest';
import { decodePolyline } from '../Utils/polyline';

describe('decodePolyline', () => {
  it('decodes the canonical encoded polyline example', () => {
    expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@')).toEqual([
      { latitude: 38.5, longitude: -120.2 },
      { latitude: 40.7, longitude: -120.95 },
      { latitude: 43.252, longitude: -126.453 },
    ]);
  });

  it('does not throw on malformed input', () => {
    expect(decodePolyline('_')).toEqual([]);
  });
});
