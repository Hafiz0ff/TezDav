import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { LineChart } from 'react-native-gifted-charts';
import { Colors } from '../DesignSystem/Colors';
import { Typography } from '../DesignSystem/Typography';
import { LiquidGlassCard } from '../DesignSystem/LiquidGlassCard';
import {
  getActivities,
  getActivityStreamSamples,
  getUserSettings,
} from '../Database/database';
import type { RootStackParamList } from '../Navigation/types';
import { ActivityMetricsEngine } from '../TrainingMetrics/ActivityMetricsEngine';
import { formatDistance, formatDuration, formatPace, sportName } from '../Utils/formatters';
import { RouteTrace } from '../Components/RouteTrace';

type Props = NativeStackScreenProps<RootStackParamList, 'ActivityDetail'>;
type ChartMetric = 'heartRate' | 'pace' | 'power' | 'elevation';

const CHARTS: Array<{ key: ChartMetric; label: string }> = [
  { key: 'heartRate', label: 'Пульс' },
  { key: 'pace', label: 'Темп' },
  { key: 'power', label: 'Мощность' },
  { key: 'elevation', label: 'Высота' },
];

export const ActivityDetailScreen = ({ route }: Props) => {
  const { width } = useWindowDimensions();
  const { activity } = route.params;
  const [chartMetric, setChartMetric] = useState<ChartMetric>('heartRate');
  const samples = useMemo(() => getActivityStreamSamples(activity.id), [activity.id]);
  const settings = useMemo(() => getUserSettings(), []);
  const splits = useMemo(() => ActivityMetricsEngine.calculateKilometerSplits(samples), [samples]);
  const zoneTimes = useMemo(
    () => ActivityMetricsEngine.calculateHeartRateZoneTimes(samples, settings.maxHeartRate, settings.restingHeartRate),
    [samples, settings.maxHeartRate, settings.restingHeartRate],
  );
  const previous = useMemo(
    () =>
      getActivities().find(
        (candidate) =>
          candidate.id !== activity.id &&
          candidate.type === activity.type &&
          Date.parse(candidate.date) < Date.parse(activity.date),
      ),
    [activity],
  );
  const chartData = useMemo(() => buildChartData(samples, chartMetric), [samples, chartMetric]);
  const totalZoneTime = zoneTimes.reduce((sum, value) => sum + value, 0);

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.title}>{activity.title}</Text>
        <Text style={styles.subtitle}>
          {sportName(activity.type)} · {new Date(activity.date).toLocaleDateString('ru-RU')}
        </Text>

        <View style={styles.primaryMetrics}>
          <Metric label="Дистанция" value={formatDistance(activity.distance, 2)} />
          <Metric label="Время" value={formatDuration(activity.duration)} />
          <Metric label="TSS" value={Math.round(activity.tss).toString()} />
        </View>

        <Text style={styles.sectionTitle}>GPS-трек</Text>
        {activity.encodedPolyline ? (
          <RouteTrace encodedPolyline={activity.encodedPolyline} />
        ) : (
          <LiquidGlassCard style={styles.emptyCard}>
            <Text style={styles.emptyTitle}>Маршрут не импортирован</Text>
            <Text style={Typography.body}>GPS-трек появится после загрузки полилинии активности.</Text>
          </LiquidGlassCard>
        )}

        <Text style={styles.sectionTitle}>Потоки</Text>
        <View style={styles.segmentedControl}>
          {CHARTS.map((chart) => (
            <Pressable
              key={chart.key}
              onPress={() => setChartMetric(chart.key)}
              style={[styles.segment, chartMetric === chart.key && styles.activeSegment]}
              accessibilityRole="tab"
              accessibilityState={{ selected: chartMetric === chart.key }}
            >
              <Text style={[styles.segmentText, chartMetric === chart.key && styles.activeSegmentText]}>{chart.label}</Text>
            </Pressable>
          ))}
        </View>
        <LiquidGlassCard style={styles.chartCard}>
          {chartData.length > 1 ? (
            <LineChart
              data={chartData}
              width={Math.max(220, width - 110)}
              height={190}
              color={Colors.accentPrimary}
              yAxisColor={Colors.glassBorder}
              xAxisColor={Colors.glassBorder}
              yAxisTextStyle={{ color: Colors.textSecondary }}
              hideDataPoints
              curved
              thickness={2}
            />
          ) : (
            <View style={styles.chartEmpty}>
              <Text style={Typography.body}>Нет данных для выбранного графика.</Text>
            </View>
          )}
        </LiquidGlassCard>

        <Text style={styles.sectionTitle}>Сплиты по километрам</Text>
        <LiquidGlassCard style={styles.listCard}>
          {splits.length === 0 ? (
            <Text style={styles.listEmpty}>Для расчёта нужен поток дистанции.</Text>
          ) : (
            splits.map((split, index) => (
              <View key={split.index} style={[styles.dataRow, index > 0 && styles.divider]}>
                <Text style={styles.dataName}>{split.index} км</Text>
                <Text style={styles.dataValue}>{formatPace(split.pace)}</Text>
                <Text style={styles.dataSecondary}>{split.avgHeartRate ? `${Math.round(split.avgHeartRate)} уд/мин` : '—'}</Text>
              </View>
            ))
          )}
        </LiquidGlassCard>

        <Text style={styles.sectionTitle}>Пульсовые зоны</Text>
        <LiquidGlassCard style={styles.zonesCard}>
          {totalZoneTime === 0 ? (
            <Text style={styles.listEmpty}>Для расчёта нужен поток пульса.</Text>
          ) : (
            zoneTimes.map((seconds, index) => (
              <View key={index} style={styles.zoneRow}>
                <Text style={styles.zoneName}>Z{index + 1}</Text>
                <View style={styles.zoneTrack}>
                  <View style={[styles.zoneFill, { width: `${Math.max(2, (seconds / totalZoneTime) * 100)}%` }]} />
                </View>
                <Text style={styles.zoneTime}>{formatDuration(seconds)}</Text>
              </View>
            ))
          )}
        </LiquidGlassCard>

        <Text style={styles.sectionTitle}>Сравнение</Text>
        <LiquidGlassCard style={styles.comparisonCard}>
          {previous ? (
            <>
              <Text style={styles.comparisonTitle}>{previous.title}</Text>
              <ComparisonRow label="Дистанция" current={activity.distance} previous={previous.distance} unit="км" divisor={1_000} lowerIsBetter={false} />
              <ComparisonRow label="Средний темп" current={pace(activity)} previous={pace(previous)} unit="с/км" lowerIsBetter />
              <ComparisonRow label="TSS" current={activity.tss} previous={previous.tss} unit="" lowerIsBetter={false} />
            </>
          ) : (
            <Text style={styles.listEmpty}>Предыдущей тренировки этого типа нет.</Text>
          )}
        </LiquidGlassCard>
      </ScrollView>
    </View>
  );
};

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue} numberOfLines={1} adjustsFontSizeToFit>{value}</Text>
    </View>
  );
}

function ComparisonRow({ label, current, previous, unit, divisor = 1, lowerIsBetter }: { label: string; current: number; previous: number; unit: string; divisor?: number; lowerIsBetter: boolean }) {
  const delta = previous === 0 ? 0 : ((current - previous) / previous) * 100;
  const improved = lowerIsBetter ? delta < 0 : delta > 0;
  return (
    <View style={styles.comparisonRow}>
      <Text style={styles.comparisonLabel}>{label}</Text>
      <Text style={styles.comparisonValue}>{(current / divisor).toFixed(1)} {unit}</Text>
      <Text style={[styles.comparisonDelta, { color: improved ? Colors.accentPrimary : delta === 0 ? Colors.textSecondary : Colors.warning }]}>
        {delta > 0 ? '+' : ''}{delta.toFixed(0)}%
      </Text>
    </View>
  );
}

function pace(activity: { distance: number; duration: number }): number {
  return activity.distance > 0 ? (activity.duration / activity.distance) * 1_000 : 0;
}

function buildChartData(samples: ReturnType<typeof getActivityStreamSamples>, metric: ChartMetric) {
  const stride = Math.max(1, Math.floor(samples.length / 160));
  return samples
    .filter((_, index) => index % stride === 0)
    .map((sample) => {
      if (metric === 'heartRate') return sample.heartRate;
      if (metric === 'power') return sample.power;
      if (metric === 'elevation') return sample.elevation;
      return sample.speed && sample.speed > 0 ? 1_000 / sample.speed : undefined;
    })
    .filter((value): value is number => value !== undefined && Number.isFinite(value))
    .map((value) => ({ value }));
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.backgroundMain },
  scrollContent: { paddingHorizontal: 18, paddingTop: 18, paddingBottom: 60 },
  title: { ...Typography.title, fontSize: 28 },
  subtitle: { ...Typography.body, marginTop: 4 },
  primaryMetrics: { flexDirection: 'row', gap: 10, marginTop: 22 },
  metric: { flex: 1, minWidth: 0, paddingVertical: 14, paddingHorizontal: 12, borderRadius: 8, backgroundColor: Colors.glassBackground, borderWidth: 1, borderColor: Colors.glassBorder },
  metricLabel: { ...Typography.caption, marginBottom: 7 },
  metricValue: { color: Colors.accentPrimary, fontSize: 21, fontWeight: '800' },
  sectionTitle: { ...Typography.title, fontSize: 20, marginTop: 26, marginBottom: 12 },
  emptyCard: { minHeight: 120, padding: 18, justifyContent: 'center' },
  emptyTitle: { ...Typography.title, fontSize: 18, marginBottom: 8 },
  segmentedControl: { flexDirection: 'row', height: 42, marginBottom: 10, padding: 3, borderRadius: 8, backgroundColor: Colors.glassBackground, borderWidth: 1, borderColor: Colors.glassBorder },
  segment: { flex: 1, alignItems: 'center', justifyContent: 'center', borderRadius: 6 },
  activeSegment: { backgroundColor: Colors.accentPrimary },
  segmentText: { ...Typography.caption, fontSize: 11, color: Colors.textSecondary },
  activeSegmentText: { color: '#001A12', fontWeight: '800' },
  chartCard: { paddingVertical: 16, paddingHorizontal: 12, minHeight: 250 },
  chartEmpty: { minHeight: 210, justifyContent: 'center', alignItems: 'center' },
  listCard: { paddingHorizontal: 16 },
  listEmpty: { ...Typography.body, paddingVertical: 18 },
  dataRow: { minHeight: 58, flexDirection: 'row', alignItems: 'center' },
  divider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.glassBorder },
  dataName: { ...Typography.body, width: 52, color: Colors.textPrimary, fontWeight: '700' },
  dataValue: { ...Typography.body, flex: 1, color: Colors.accentPrimary, fontWeight: '800' },
  dataSecondary: { ...Typography.caption, color: Colors.textSecondary },
  zonesCard: { padding: 16 },
  zoneRow: { flexDirection: 'row', alignItems: 'center', minHeight: 38 },
  zoneName: { ...Typography.caption, width: 28, color: Colors.textPrimary },
  zoneTrack: { flex: 1, height: 7, borderRadius: 4, backgroundColor: Colors.glassBorder, overflow: 'hidden' },
  zoneFill: { height: '100%', borderRadius: 4, backgroundColor: Colors.accentPrimary },
  zoneTime: { ...Typography.caption, width: 58, textAlign: 'right', color: Colors.textSecondary },
  comparisonCard: { paddingHorizontal: 16 },
  comparisonTitle: { ...Typography.body, color: Colors.textPrimary, fontWeight: '800', paddingVertical: 15 },
  comparisonRow: { minHeight: 48, flexDirection: 'row', alignItems: 'center', borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.glassBorder },
  comparisonLabel: { ...Typography.caption, flex: 1 },
  comparisonValue: { ...Typography.body, color: Colors.textPrimary, marginRight: 12 },
  comparisonDelta: { width: 48, textAlign: 'right', fontWeight: '800' },
});
