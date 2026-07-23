import React, { useMemo, useState } from 'react';
import { LayoutChangeEvent, Pressable, StyleSheet, Text, View } from 'react-native';
import Svg, {
  Circle,
  Defs,
  Line,
  LinearGradient as SvgLinearGradient,
  Path,
  Stop,
} from 'react-native-svg';
import type { PMCMetrics } from '../TrainingMetrics/TrainingLoadCalculator';
import { Colors } from '../DesignSystem/Colors';
import { Radii, Spacing } from '../DesignSystem/DesignTokens';
import { GlassSurface } from '../DesignSystem/GlassSurface';
import { Typography } from '../DesignSystem/Typography';
import { EmptyState } from './EmptyState';
import { ChartNoAxesCombined } from 'lucide-react-native';

type SeriesKey = 'ctl' | 'atl' | 'tsb';
const series: Array<{ key: SeriesKey; label: string; color: string }> = [
  { key: 'ctl', label: 'CTL', color: Colors.accentPrimary },
  { key: 'atl', label: 'ATL', color: Colors.warning },
  { key: 'tsb', label: 'TSB', color: Colors.textSecondary },
];

export function PmcChart({ data }: { data: PMCMetrics[] }) {
  const [width, setWidth] = useState(0);
  const [visible, setVisible] = useState<Record<SeriesKey, boolean>>({ ctl: true, atl: true, tsb: true });
  const [selected, setSelected] = useState<number | null>(null);
  const plotHeight = 220;
  const horizontalPadding = 12;
  const points = useMemo(() => buildGeometry(data, Math.max(1, width - horizontalPadding * 2), plotHeight), [data, width]);
  const activePoint = selected === null ? null : data[selected];
  const activeX = selected === null || data.length < 2
    ? 0
    : horizontalPadding + (selected / (data.length - 1)) * Math.max(1, width - horizontalPadding * 2);

  const selectAt = (locationX: number) => {
    if (data.length < 2 || width <= 0) return;
    const normalized = Math.max(0, Math.min(1, (locationX - horizontalPadding) / Math.max(1, width - horizontalPadding * 2)));
    setSelected(Math.round(normalized * (data.length - 1)));
  };
  const onLayout = (event: LayoutChangeEvent) => setWidth(event.nativeEvent.layout.width);

  return (
    <View>
      <View style={styles.legend}>
        {series.map((item) => (
          <Pressable
            key={item.key}
            onPress={() => setVisible((current) => ({ ...current, [item.key]: !current[item.key] }))}
            accessibilityRole="checkbox"
            accessibilityState={{ checked: visible[item.key] }}
          >
            <GlassSurface radius={Radii.pill} tint={visible[item.key] ? 'emerald' : 'neutral'} style={styles.chip}>
              <View style={[styles.legendDot, { backgroundColor: item.color, opacity: visible[item.key] ? 1 : 0.35 }]} />
              <Text style={[styles.chipText, !visible[item.key] && styles.chipMuted]}>{item.label}</Text>
            </GlassSurface>
          </Pressable>
        ))}
      </View>

      <View
        onLayout={onLayout}
        style={styles.plot}
        onStartShouldSetResponder={() => data.length > 1}
        onMoveShouldSetResponder={() => data.length > 1}
        onResponderGrant={(event) => selectAt(event.nativeEvent.locationX)}
        onResponderMove={(event) => selectAt(event.nativeEvent.locationX)}
        onResponderRelease={() => undefined}
        accessibilityLabel="График формы CTL, ATL и TSB"
      >
        {data.length > 1 && width > 0 ? (
          <>
            <Svg width={width} height={plotHeight + 34}>
              <Defs>
                <SvgLinearGradient id="ctlFill" x1="0" y1="0" x2="0" y2="1">
                  <Stop offset="0" stopColor={Colors.accentPrimary} stopOpacity="0.24" />
                  <Stop offset="1" stopColor={Colors.accentPrimary} stopOpacity="0" />
                </SvgLinearGradient>
                <SvgLinearGradient id="atlFill" x1="0" y1="0" x2="0" y2="1">
                  <Stop offset="0" stopColor={Colors.warning} stopOpacity="0.13" />
                  <Stop offset="1" stopColor={Colors.warning} stopOpacity="0" />
                </SvgLinearGradient>
              </Defs>
              {[0.25, 0.5, 0.75].map((fraction) => (
                <Line key={fraction} x1={horizontalPadding} x2={width - horizontalPadding} y1={plotHeight * fraction} y2={plotHeight * fraction} stroke={Colors.divider} strokeWidth="1" />
              ))}
              {points.zeroY >= 0 && points.zeroY <= plotHeight && (
                <Line x1={horizontalPadding} x2={width - horizontalPadding} y1={points.zeroY} y2={points.zeroY} stroke={Colors.textMuted} strokeOpacity="0.55" strokeDasharray="5 6" />
              )}
              {visible.ctl && <Path d={points.ctlArea} fill="url(#ctlFill)" />}
              {visible.atl && <Path d={points.atlArea} fill="url(#atlFill)" />}
              {visible.ctl && <Path d={points.ctl} fill="none" stroke={Colors.accentPrimary} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />}
              {visible.atl && <Path d={points.atl} fill="none" stroke={Colors.warning} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />}
              {visible.tsb && <Path d={points.tsb} fill="none" stroke={Colors.textSecondary} strokeWidth="1.5" strokeDasharray="5 5" />}
              {activePoint && (
                <>
                  <Line x1={activeX} x2={activeX} y1="4" y2={plotHeight} stroke={Colors.textPrimary} strokeOpacity="0.3" />
                  <Circle cx={activeX} cy={points.pointY.ctl[selected ?? 0]} r="4" fill={Colors.accentPrimary} stroke={Colors.surface} strokeWidth="2" />
                </>
              )}
            </Svg>
            <View pointerEvents="none" style={styles.axisLabels}>
              <Text style={styles.axisText}>{data[0]?.date.toLocaleDateString('ru-RU', { day: '2-digit', month: 'short' })}</Text>
              <Text style={styles.axisText}>{data.at(-1)?.date.toLocaleDateString('ru-RU', { day: '2-digit', month: 'short' })}</Text>
            </View>
            {activePoint && (
              <GlassSurface
                radius={Radii.small}
                style={[styles.tooltip, { left: Math.max(8, Math.min(width - 164, activeX - 78)) }]}
              >
                <Text style={styles.tooltipDate}>{activePoint.date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })}</Text>
                <Text style={styles.tooltipValues}>CTL {activePoint.ctl.toFixed(1)} · ATL {activePoint.atl.toFixed(1)} · TSB {activePoint.tsb.toFixed(1)}</Text>
              </GlassSurface>
            )}
          </>
        ) : (
          <View style={styles.emptyWrap}>
            <Svg width="100%" height={92} style={styles.ghostChart}>
              <Path d="M 10 70 C 45 68, 55 30, 90 48 S 150 22, 190 46 S 245 30, 300 18" fill="none" stroke={Colors.textMuted} strokeOpacity="0.35" strokeDasharray="6 7" strokeWidth="2" />
            </Svg>
            <EmptyState
              icon={ChartNoAxesCombined}
              title="Нужна история нагрузок"
              description="График появится после импорта нескольких тренировок с TSS."
              compact
            />
          </View>
        )}
      </View>
    </View>
  );
}

function buildGeometry(data: PMCMetrics[], width: number, height: number) {
  const allValues = data.flatMap((point) => [point.ctl, point.atl, point.tsb]);
  const minimum = Math.min(0, ...allValues);
  const maximum = Math.max(1, ...allValues);
  const padding = Math.max(4, (maximum - minimum) * 0.08);
  const low = minimum - padding;
  const high = maximum + padding;
  const y = (value: number) => height - ((value - low) / Math.max(1, high - low)) * height;
  const x = (index: number) => 12 + (index / Math.max(1, data.length - 1)) * width;
  const pathFor = (key: SeriesKey) => data.map((point, index) => `${index === 0 ? 'M' : 'L'} ${x(index).toFixed(1)} ${y(point[key]).toFixed(1)}`).join(' ');
  const areaFor = (key: 'ctl' | 'atl') => `${pathFor(key)} L ${x(data.length - 1).toFixed(1)} ${height} L 12 ${height} Z`;
  return {
    ctl: pathFor('ctl'),
    atl: pathFor('atl'),
    tsb: pathFor('tsb'),
    ctlArea: areaFor('ctl'),
    atlArea: areaFor('atl'),
    zeroY: y(0),
    pointY: {
      ctl: data.map((point) => y(point.ctl)),
      atl: data.map((point) => y(point.atl)),
      tsb: data.map((point) => y(point.tsb)),
    },
  };
}

const styles = StyleSheet.create({
  legend: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.xs, marginBottom: Spacing.md },
  chip: { minHeight: 34, paddingHorizontal: 12, flexDirection: 'row', alignItems: 'center', gap: 7 },
  legendDot: { width: 7, height: 7, borderRadius: 4 },
  chipText: { ...Typography.caption, color: Colors.textPrimary, fontWeight: '700' },
  chipMuted: { color: Colors.textMuted },
  plot: { minHeight: 254, overflow: 'visible' },
  axisLabels: { position: 'absolute', left: 12, right: 12, bottom: 2, flexDirection: 'row', justifyContent: 'space-between' },
  axisText: { ...Typography.caption, fontSize: 11 },
  tooltip: { position: 'absolute', top: 6, width: 156, padding: 10 },
  tooltipDate: { ...Typography.caption, color: Colors.textPrimary, fontWeight: '700' },
  tooltipValues: { ...Typography.caption, marginTop: 3, color: Colors.textSecondary, fontSize: 11 },
  emptyWrap: { minHeight: 300, justifyContent: 'center' },
  ghostChart: { position: 'absolute', left: 0, right: 0, top: 16 },
});
