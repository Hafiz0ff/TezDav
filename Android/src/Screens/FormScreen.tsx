import React, { useCallback, useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { Colors } from '../DesignSystem/Colors';
import { ContentCard } from '../DesignSystem/ContentCard';
import { Spacing } from '../DesignSystem/DesignTokens';
import { ScreenScrollView } from '../DesignSystem/ScreenScrollView';
import { Typography } from '../DesignSystem/Typography';
import { getActivities } from '../Database/database';
import { TrainingLoadCalculator, PMCMetrics } from '../TrainingMetrics/TrainingLoadCalculator';
import { GlassSegmentedControl } from '../Components/GlassSegmentedControl';
import { MetricTile } from '../Components/MetricTile';
import { PmcChart } from '../Components/PmcChart';
import { SectionTitle } from '../Components/SectionTitle';

type Period = 30 | 90 | 0;
const periodOptions: Array<{ value: Period; label: string }> = [
  { value: 30, label: '30 дн.' },
  { value: 90, label: '90 дн.' },
  { value: 0, label: 'Всё' },
];

export const FormScreen = () => {
  const [allPmcData, setAllPmcData] = useState<PMCMetrics[]>([]);
  const [period, setPeriod] = useState<Period>(90);

  useFocusEffect(
    useCallback(() => {
      const activities = getActivities();
      setAllPmcData(
        TrainingLoadCalculator.calculatePMC(
          activities.map((activity) => ({ date: new Date(activity.date), tss: activity.tss })),
        ),
      );
    }, []),
  );

  const pmcData = useMemo(
    () => (period === 0 ? allPmcData : allPmcData.slice(-period)),
    [allPmcData, period],
  );
  const current = allPmcData.at(-1);

  return (
    <ScreenScrollView title="Форма" subtitle="Performance Management Chart">
      <ContentCard style={styles.metricsCard}>
        <View style={styles.metricRow}>
          <MetricTile label="Фитнес · CTL" value={current ? current.ctl.toFixed(1) : '—'} color={current ? Colors.accentPrimary : Colors.textPrimary} />
          <MetricTile label="Усталость · ATL" value={current ? current.atl.toFixed(1) : '—'} color={current ? Colors.warning : Colors.textPrimary} />
          <MetricTile
            label="Баланс · TSB"
            value={current ? `${current.tsb > 0 ? '+' : ''}${current.tsb.toFixed(1)}` : '—'}
            color={current && current.tsb < -10 ? Colors.danger : Colors.textPrimary}
          />
        </View>
        <View style={styles.divider} />
        <Text style={styles.description}>{formDescription(allPmcData.length, current?.tsb ?? 0)}</Text>
      </ContentCard>

      <View style={styles.periodControl}>
        <GlassSegmentedControl options={periodOptions} value={period} onChange={setPeriod} />
      </View>

      <SectionTitle title="Динамика нагрузки" />
      <ContentCard style={styles.chartCard}>
        <PmcChart data={pmcData} />
      </ContentCard>

      <Text style={styles.chartHint}>
        Нажмите или проведите по графику, чтобы увидеть значения за конкретный день. Легенда скрывает и показывает линии.
      </Text>
    </ScreenScrollView>
  );
};

function formDescription(pointCount: number, tsb: number): string {
  if (pointCount === 0) return 'Оценка появится после импорта нагрузок.';
  if (tsb > 5) return 'Вы относительно свежи: острая нагрузка снизилась.';
  if (tsb < -10) return 'Усталость повышена. Учтите восстановление в следующей тренировке.';
  return 'Нагрузка и восстановление находятся в рабочем диапазоне.';
}

const styles = StyleSheet.create({
  metricsCard: { padding: Spacing.lg },
  metricRow: { flexDirection: 'row', gap: Spacing.sm },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.divider, marginVertical: Spacing.md },
  description: { ...Typography.subheadline, color: Colors.textSecondary },
  periodControl: { marginTop: Spacing.md },
  chartCard: { padding: Spacing.md },
  chartHint: { ...Typography.caption, color: Colors.textSecondary, marginTop: Spacing.sm, paddingHorizontal: Spacing.xs },
});
