import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { CompositeNavigationProp } from '@react-navigation/native';
import type { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Activity as ActivityIcon, ChevronRight, Footprints, Import, Sparkles } from 'lucide-react-native';
import { Colors } from '../DesignSystem/Colors';
import { ContentCard } from '../DesignSystem/ContentCard';
import { Radii, Spacing } from '../DesignSystem/DesignTokens';
import { ScreenScrollView } from '../DesignSystem/ScreenScrollView';
import { Typography } from '../DesignSystem/Typography';
import { Activity, getActivities } from '../Database/database';
import {
  fetchTodaySteps,
  getHealthConnectStatus,
  HealthConnectStatus,
  requestHealthConnectAccess,
} from '../Health/healthConnect';
import type { RootStackParamList, RootTabParamList } from '../Navigation/types';
import { TrainingLoadCalculator } from '../TrainingMetrics/TrainingLoadCalculator';
import { ActivityRow } from '../Components/ActivityRow';
import { EmptyState } from '../Components/EmptyState';
import { GlassButton } from '../Components/GlassButton';
import { MetricTile } from '../Components/MetricTile';
import { SectionTitle } from '../Components/SectionTitle';
import { formatDistance, formatDuration, sportName } from '../Utils/formatters';

type DashboardNavigation = CompositeNavigationProp<
  BottomTabNavigationProp<RootTabParamList, 'Dashboard'>,
  NativeStackNavigationProp<RootStackParamList>
>;

export const DashboardScreen = () => {
  const navigation = useNavigation<DashboardNavigation>();
  const [activities, setActivities] = useState<Activity[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [steps, setSteps] = useState<number | null>(null);
  const [healthStatus, setHealthStatus] = useState<HealthConnectStatus>('unavailable');
  const [isRequestingHealth, setIsRequestingHealth] = useState(false);

  useFocusEffect(
    useCallback(() => {
      try {
        setActivities(getActivities());
        setLoadError(null);
      } catch {
        setLoadError('Не удалось прочитать локальные тренировки.');
      }
    }, []),
  );

  useEffect(() => {
    let isMounted = true;
    const loadHealthStatus = async () => {
      const status = await getHealthConnectStatus();
      if (!isMounted) return;
      setHealthStatus(status);
      if (status === 'ready') setSteps(await fetchTodaySteps());
    };
    void loadHealthStatus();
    return () => { isMounted = false; };
  }, []);

  const pmc = useMemo(
    () => TrainingLoadCalculator.calculatePMC(
      activities.map((activity) => ({ date: new Date(activity.date), tss: activity.tss })),
    ),
    [activities],
  );
  const current = pmc.at(-1);

  const weeklyBySport = useMemo(() => {
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const grouped = new Map<string, { distance: number; duration: number; count: number }>();
    for (const activity of activities) {
      if (Date.parse(activity.date) < weekAgo) continue;
      const label = sportName(activity.type);
      const previous = grouped.get(label) ?? { distance: 0, duration: 0, count: 0 };
      grouped.set(label, {
        distance: previous.distance + activity.distance,
        duration: previous.duration + activity.duration,
        count: previous.count + 1,
      });
    }
    return [...grouped.entries()];
  }, [activities]);

  const connectHealth = async () => {
    setIsRequestingHealth(true);
    try {
      const granted = await requestHealthConnectAccess();
      setHealthStatus(granted ? 'ready' : 'permission-required');
      setSteps(granted ? await fetchTodaySteps() : null);
    } finally {
      setIsRequestingHealth(false);
    }
  };

  return (
    <ScreenScrollView title="TezDav" subtitle="Состояние и нагрузка">
      <Pressable
        onPress={() => navigation.navigate('Form')}
        accessibilityRole="button"
        accessibilityLabel="Открыть экран формы"
        style={({ pressed }) => pressed && styles.pressed}
      >
        <ContentCard style={styles.loadCard}>
          <View style={styles.cardEyebrow}>
            <View style={styles.eyebrowTitle}>
              <Sparkles color={Colors.accentPrimary} size={16} />
              <Text style={styles.eyebrowText}>Текущая форма</Text>
            </View>
            <ChevronRight color={Colors.textMuted} size={20} />
          </View>
          <View style={styles.metricRow}>
            <MetricTile label="Фитнес · CTL" value={current ? current.ctl.toFixed(1) : '—'} color={current ? Colors.accentPrimary : Colors.textPrimary} />
            <MetricTile label="Усталость · ATL" value={current ? current.atl.toFixed(1) : '—'} color={current ? Colors.warning : Colors.textPrimary} />
            <MetricTile
              label="Форма · TSB"
              value={current ? `${current.tsb > 0 ? '+' : ''}${current.tsb.toFixed(1)}` : '—'}
              color={current && current.tsb < -10 ? Colors.danger : Colors.textPrimary}
            />
          </View>
          <Text style={styles.loadHint}>{current ? formDescription(current.tsb) : 'Импортируйте тренировки для расчёта формы.'}</Text>
        </ContentCard>
      </Pressable>

      <SectionTitle title="Последние 7 дней" />
      <ContentCard style={styles.summaryCard}>
        {weeklyBySport.length === 0 ? (
          <EmptyState
            icon={ActivityIcon}
            title="Спокойная неделя"
            description="Здесь появятся объём и время тренировок за семь дней."
            compact
          />
        ) : (
          weeklyBySport.map(([sport, summary], index) => (
            <View key={sport} style={[styles.summaryRow, index > 0 && styles.rowDivider]}>
              <View style={styles.summaryName}>
                <Text style={styles.summarySport}>{sport}</Text>
                <Text style={styles.summaryCount}>{summary.count} тренировок</Text>
              </View>
              <View style={styles.summaryNumbers}>
                <Text style={styles.summaryValue}>{formatDistance(summary.distance)}</Text>
                <Text style={styles.summaryDuration}>{formatDuration(summary.duration)}</Text>
              </View>
            </View>
          ))
        )}
      </ContentCard>

      {healthStatus === 'ready' && steps !== null && (
        <ContentCard style={styles.healthCard}>
          <View style={styles.healthIcon}><Footprints color={Colors.accentPrimary} size={22} /></View>
          <View style={styles.healthText}>
            <Text style={styles.healthLabel}>Шаги сегодня</Text>
            <Text style={styles.healthSource}>Health Connect</Text>
          </View>
          <Text style={styles.healthValue}>{steps.toLocaleString('ru-RU')}</Text>
        </ContentCard>
      )}

      {healthStatus === 'permission-required' && (
        <GlassButton
          label={isRequestingHealth ? 'Запрос разрешения…' : 'Подключить Health Connect'}
          icon={<Footprints color={Colors.accentPrimary} size={20} />}
          onPress={() => void connectHealth()}
          disabled={isRequestingHealth}
          style={styles.healthButton}
        />
      )}

      <SectionTitle
        title="Последние тренировки"
        accessory={activities.length > 0 ? (
          <Pressable onPress={() => navigation.navigate('Activities')} accessibilityRole="button">
            <Text style={styles.link}>Все</Text>
          </Pressable>
        ) : undefined}
      />

      {loadError ? (
        <Text style={styles.errorText}>{loadError}</Text>
      ) : activities.length === 0 ? (
        <ContentCard>
          <EmptyState
            icon={Import}
            title="Тренировок пока нет"
            description="После импорта здесь появятся последние активности и их нагрузка."
            actionLabel="Импортировать активность"
          />
        </ContentCard>
      ) : (
        <ContentCard>
          {activities.slice(0, 5).map((activity) => (
            <ActivityRow
              key={activity.id}
              activity={activity}
              onPress={() => navigation.navigate('ActivityDetail', { activity })}
            />
          ))}
        </ContentCard>
      )}
    </ScreenScrollView>
  );
};

function formDescription(tsb: number): string {
  if (tsb > 5) return 'Нагрузка снизилась: вы относительно свежи.';
  if (tsb < -10) return 'Накоплена заметная усталость.';
  return 'Нагрузка и восстановление в рабочем балансе.';
}

const styles = StyleSheet.create({
  pressed: { opacity: 0.82, transform: [{ scale: 0.995 }] },
  loadCard: { padding: Spacing.lg },
  cardEyebrow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: Spacing.md },
  eyebrowTitle: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  eyebrowText: { ...Typography.caption, color: Colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.7 },
  metricRow: { flexDirection: 'row', gap: Spacing.sm },
  loadHint: { ...Typography.caption, color: Colors.textSecondary, marginTop: Spacing.lg },
  summaryCard: { paddingHorizontal: Spacing.md },
  summaryRow: { minHeight: 76, flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  rowDivider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.divider },
  summaryName: { flex: 1 },
  summarySport: { ...Typography.headline },
  summaryCount: { ...Typography.caption, marginTop: 3 },
  summaryNumbers: { alignItems: 'flex-end' },
  summaryValue: { ...Typography.headline, color: Colors.textPrimary, fontVariant: ['tabular-nums'] },
  summaryDuration: { ...Typography.caption, marginTop: 3, fontVariant: ['tabular-nums'] },
  healthCard: { marginTop: Spacing.sm, padding: Spacing.md, flexDirection: 'row', alignItems: 'center' },
  healthIcon: { width: 44, height: 44, borderRadius: Radii.small, backgroundColor: Colors.accentTint, alignItems: 'center', justifyContent: 'center' },
  healthText: { flex: 1, marginLeft: Spacing.sm },
  healthLabel: { ...Typography.headline, fontSize: 15 },
  healthSource: { ...Typography.caption, marginTop: 2 },
  healthValue: { ...Typography.metric, color: Colors.textPrimary },
  healthButton: { marginTop: Spacing.sm },
  link: { ...Typography.headline, fontSize: 15, color: Colors.accentPrimary, padding: 8 },
  errorText: { ...Typography.body, color: Colors.danger },
});
