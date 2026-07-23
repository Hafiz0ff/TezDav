import React, { useCallback, useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { Activity, getActivities, getActivityStreamSamples } from '../Database/database';
import { Colors } from '../DesignSystem/Colors';
import { ContentCard } from '../DesignSystem/ContentCard';
import { Radii, Spacing } from '../DesignSystem/DesignTokens';
import { ScreenScrollView } from '../DesignSystem/ScreenScrollView';
import { Typography } from '../DesignSystem/Typography';
import {
  AnalyticsEngine,
  DistanceRecord,
  STANDARD_RUNNING_DISTANCES,
} from '../TrainingMetrics/AnalyticsEngine';
import { MetricTile } from '../Components/MetricTile';
import { RecordRow } from '../Components/RecordRow';
import { SectionTitle } from '../Components/SectionTitle';
import { formatDistance, formatDuration, isRunning } from '../Utils/formatters';

export function RecordsScreen() {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [records, setRecords] = useState<DistanceRecord[]>([]);

  useFocusEffect(
    useCallback(() => {
      const allActivities = getActivities();
      setActivities(allActivities);
      setRecords(calculateRecords(allActivities));
    }, []),
  );

  const report = useMemo(() => periodReport(activities), [activities]);
  const fiveKilometerRecord = records.find((record) => record.distanceMeters === 5_000);
  const vo2max = fiveKilometerRecord?.durationSeconds
    ? AnalyticsEngine.estimateDanielsVO2Max(5_000, fiveKilometerRecord.durationSeconds)
    : null;
  const halfPrediction = fiveKilometerRecord?.durationSeconds
    ? AnalyticsEngine.predictRiegelTime(5_000, fiveKilometerRecord.durationSeconds, 21_097.5)
    : null;
  const marathonPrediction = fiveKilometerRecord?.durationSeconds
    ? AnalyticsEngine.predictRiegelTime(5_000, fiveKilometerRecord.durationSeconds, 42_195)
    : null;

  return (
    <ScreenScrollView title="Рекорды" subtitle="Лучшие отрезки и динамика">
      <SectionTitle title="Бег" />
      <ContentCard style={styles.recordsCard}>
        {STANDARD_RUNNING_DISTANCES.map((distance, index) => {
          const record = records.find((item) => item.distanceMeters === distance.meters);
          return (
            <RecordRow
              key={distance.meters}
              label={distance.label}
              status={record?.activityTitle ?? 'Нет потока дистанции'}
              value={record?.durationSeconds ? formatDuration(record.durationSeconds) : undefined}
              isFirst={index === 0}
            />
          );
        })}
      </ContentCard>

      <SectionTitle title="Оценки" />
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.horizontalCards}
        accessibilityRole="list"
      >
        <EstimateCard label="VO₂max" method="Daniels" value={vo2max ? vo2max.toFixed(1) : '—'} accent={Boolean(vo2max)} />
        <EstimateCard label="Полумарафон" method="Riegel" value={halfPrediction ? formatDuration(halfPrediction) : '—'} />
        <EstimateCard label="Марафон" method="Riegel" value={marathonPrediction ? formatDuration(marathonPrediction) : '—'} />
      </ScrollView>
      {!fiveKilometerRecord?.durationSeconds && (
        <Text style={styles.caption}>Для оценок нужен посекундный поток дистанции хотя бы одной пробежки на 5 км.</Text>
      )}

      <SectionTitle title="Последние 30 дней" />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.horizontalCards}>
        <ReportCard label="Тренировки" value={String(report.current.count)} detail="за период" />
        <ReportCard label="Дистанция" value={formatDistance(report.current.distance)} detail={formatDelta(report.current.distance, report.previous.distance)} />
        <ReportCard label="Время" value={formatDuration(report.current.duration)} detail={formatDelta(report.current.duration, report.previous.duration)} />
      </ScrollView>
    </ScreenScrollView>
  );
}

function EstimateCard({ label, method, value, accent = false }: { label: string; method: string; value: string; accent?: boolean }) {
  return (
    <ContentCard style={styles.estimateCard}>
      <Text style={styles.cardLabel}>{label}</Text>
      <Text style={styles.cardMethod}>{method}</Text>
      <Text style={[styles.cardValue, accent && styles.accentValue]} numberOfLines={1} adjustsFontSizeToFit>{value}</Text>
    </ContentCard>
  );
}

function ReportCard({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <ContentCard style={styles.reportCard}>
      <MetricTile label={label} value={value} style={styles.metricReset} />
      <Text style={styles.reportDetail} numberOfLines={2}>{detail}</Text>
    </ContentCard>
  );
}

function calculateRecords(activities: Activity[]): DistanceRecord[] {
  const best = new Map<number, DistanceRecord>();
  for (const activity of activities) {
    if (!isRunning(activity.type) || !activity.streamsImported) continue;
    const samples = getActivityStreamSamples(activity.id);
    for (const distance of STANDARD_RUNNING_DISTANCES) {
      if (activity.distance + 20 < distance.meters) continue;
      const duration = AnalyticsEngine.findBestEffort(samples, distance.meters);
      if (duration === null) continue;
      const current = best.get(distance.meters);
      if (!current?.durationSeconds || duration < current.durationSeconds) {
        best.set(distance.meters, {
          distanceMeters: distance.meters,
          durationSeconds: duration,
          activityId: activity.id,
          activityTitle: activity.title,
          activityDate: activity.date,
        });
      }
    }
  }
  return [...best.values()];
}

function periodReport(activities: Activity[]) {
  const now = Date.now();
  const thirtyDays = 30 * 24 * 60 * 60 * 1000;
  const summarize = (from: number, to: number) => activities.reduce(
    (summary, activity) => {
      const timestamp = Date.parse(activity.date);
      if (timestamp >= from && timestamp < to) {
        summary.count++;
        summary.distance += activity.distance;
        summary.duration += activity.duration;
      }
      return summary;
    },
    { count: 0, distance: 0, duration: 0 },
  );
  return {
    current: summarize(now - thirtyDays, now + 1),
    previous: summarize(now - 2 * thirtyDays, now - thirtyDays),
  };
}

function formatDelta(current: number, previous: number): string {
  if (previous <= 0) return 'нет базы сравнения';
  const change = ((current - previous) / previous) * 100;
  return `${change > 0 ? '+' : ''}${change.toFixed(0)}% к прошлым 30 дням`;
}

const styles = StyleSheet.create({
  recordsCard: { paddingHorizontal: Spacing.md },
  horizontalCards: { gap: Spacing.sm, paddingRight: Spacing.screen },
  estimateCard: { width: 148, minHeight: 132, padding: Spacing.md, justifyContent: 'space-between' },
  reportCard: { width: 156, minHeight: 142, padding: Spacing.md },
  cardLabel: { ...Typography.headline },
  cardMethod: { ...Typography.caption, marginTop: 2 },
  cardValue: { ...Typography.metricLarge, color: Colors.textPrimary, marginTop: Spacing.lg },
  accentValue: { color: Colors.accentPrimary },
  caption: { ...Typography.caption, color: Colors.textSecondary, marginTop: Spacing.sm, lineHeight: 18 },
  metricReset: { flex: 0, minWidth: 0 },
  reportDetail: { ...Typography.caption, marginTop: Spacing.md, minHeight: 34 },
});
