export interface Coordinate {
  latitude: number;
  longitude: number;
}

export function decodePolyline(encoded: string, precision = 5): Coordinate[] {
  const coordinates: Coordinate[] = [];
  const factor = Math.pow(10, precision);
  let latitude = 0;
  let longitude = 0;
  let index = 0;

  while (index < encoded.length) {
    const latitudeChunk = decodeChunk(encoded, index);
    if (!latitudeChunk) break;
    index = latitudeChunk.nextIndex;
    const longitudeChunk = decodeChunk(encoded, index);
    if (!longitudeChunk) break;
    index = longitudeChunk.nextIndex;
    latitude += latitudeChunk.delta;
    longitude += longitudeChunk.delta;
    coordinates.push({ latitude: latitude / factor, longitude: longitude / factor });
  }
  return coordinates;
}

function decodeChunk(encoded: string, startIndex: number): { delta: number; nextIndex: number } | null {
  let result = 0;
  let shift = 0;
  let index = startIndex;
  let byte: number;
  do {
    if (index >= encoded.length || shift > 30) return null;
    byte = encoded.charCodeAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  return {
    delta: result & 1 ? ~(result >> 1) : result >> 1,
    nextIndex: index,
  };
}
