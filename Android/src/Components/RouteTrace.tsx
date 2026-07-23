import React, { useMemo } from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Polyline } from 'react-native-svg';
import { Colors } from '../DesignSystem/Colors';
import { decodePolyline } from '../Utils/polyline';

export function RouteTrace({ encodedPolyline }: { encodedPolyline: string }) {
  const points = useMemo(() => {
    const coordinates = decodePolyline(encodedPolyline);
    if (coordinates.length < 2) return '';
    const width = 320;
    const height = 170;
    const padding = 14;
    const latitudes = coordinates.map((coordinate) => coordinate.latitude);
    const longitudes = coordinates.map((coordinate) => coordinate.longitude);
    const minLatitude = Math.min(...latitudes);
    const maxLatitude = Math.max(...latitudes);
    const minLongitude = Math.min(...longitudes);
    const maxLongitude = Math.max(...longitudes);
    const latitudeSpan = Math.max(maxLatitude - minLatitude, 0.000001);
    const longitudeSpan = Math.max(maxLongitude - minLongitude, 0.000001);
    return coordinates
      .map((coordinate) => {
        const x = padding + ((coordinate.longitude - minLongitude) / longitudeSpan) * (width - 2 * padding);
        const y = height - padding - ((coordinate.latitude - minLatitude) / latitudeSpan) * (height - 2 * padding);
        return `${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(' ');
  }, [encodedPolyline]);

  return (
    <View style={styles.container}>
      <Svg width="100%" height="100%" viewBox="0 0 320 170">
        <Polyline points={points} fill="none" stroke="rgba(16,185,129,0.22)" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round" />
        <Polyline points={points} fill="none" stroke={Colors.accentPrimary} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: 190,
    backgroundColor: '#0B1713',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.glassBorder,
    overflow: 'hidden',
  },
});
