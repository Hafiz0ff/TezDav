import React, { useCallback, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { Cloud, CloudOff, Pencil, Save } from 'lucide-react-native';
import {
  getSyncState,
  getUserSettings,
  saveUserSettings,
  SyncState,
  UserSettings,
} from '../Database/database';
import { Colors } from '../DesignSystem/Colors';
import { ContentCard } from '../DesignSystem/ContentCard';
import { Radii, Spacing } from '../DesignSystem/DesignTokens';
import { ScreenScrollView } from '../DesignSystem/ScreenScrollView';
import { Typography } from '../DesignSystem/Typography';
import { GlassButton } from '../Components/GlassButton';
import { GlassSegmentedControl } from '../Components/GlassSegmentedControl';
import { SectionTitle } from '../Components/SectionTitle';
import { formatPace } from '../Utils/formatters';

const SPORTS = [
  { value: 'Running', label: 'Бег' },
  { value: 'Cycling', label: 'Вело' },
  { value: 'Triathlon', label: 'Триатлон' },
] as const;

interface SettingsForm {
  maxHeartRate: string;
  restingHeartRate: string;
  thresholdPace: string;
  targetWeeklyKm: string;
  cyclingFTP: string;
  mainSport: string;
}

export function ProfileScreen() {
  const [form, setForm] = useState<SettingsForm | null>(null);
  const [syncState, setSyncState] = useState<SyncState | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useFocusEffect(
    useCallback(() => {
      try {
        setForm(toForm(getUserSettings()));
        setSyncState(getSyncState());
        setError(null);
      } catch {
        setError('Не удалось загрузить локальные настройки.');
      }
    }, []),
  );

  const update = (key: keyof SettingsForm, value: string) => {
    setForm((current) => (current ? { ...current, [key]: value } : current));
    setMessage(null);
  };

  const save = () => {
    if (!form) return;
    try {
      saveUserSettings({
        maxHeartRate: parsePositive(form.maxHeartRate),
        restingHeartRate: parsePositive(form.restingHeartRate),
        runningThresholdPaceSecondsPerKm: parsePace(form.thresholdPace),
        targetWeeklyDistanceMeters: parsePositive(form.targetWeeklyKm) * 1_000,
        cyclingFTP: parsePositive(form.cyclingFTP),
        mainSport: form.mainSport,
      });
      setForm(toForm(getUserSettings()));
      setError(null);
      setMessage('Настройки сохранены на устройстве.');
    } catch (saveError) {
      setMessage(null);
      setError(saveError instanceof Error ? saveError.message : 'Не удалось сохранить настройки.');
    }
  };

  if (!form) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorText}>{error ?? 'Загрузка…'}</Text>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScreenScrollView
        title="Профиль"
        subtitle="Пороговые значения и цели"
        keyboardShouldPersistTaps="handled"
      >
        <SectionTitle title="Strava" />
        <ContentCard style={styles.syncCard}>
          <View style={styles.syncHeader}>
            <View style={styles.providerIcon}>
              {syncState?.connected
                ? <Cloud color={Colors.accentPrimary} size={24} />
                : <CloudOff color={Colors.textSecondary} size={24} />}
            </View>
            <View style={styles.syncText}>
              <Text style={styles.syncTitle}>
                {syncState?.connected ? syncState.athleteName ?? 'Подключено' : 'Не подключено'}
              </Text>
              <Text style={styles.syncSubtitle}>
                {syncState?.lastSyncedAt
                  ? `Последняя синхронизация ${new Date(syncState.lastSyncedAt).toLocaleString('ru-RU')}`
                  : 'Импорт тренировок и маршрутов из вашего аккаунта.'}
              </Text>
            </View>
          </View>
          {!syncState?.connected && (
            <>
              <GlassButton label="Подключить Strava" disabled style={styles.connectButton} />
              <Text style={styles.providerNote}>Подключение станет доступно после настройки безопасной синхронизации.</Text>
            </>
          )}
        </ContentCard>

        <SectionTitle title="Основной спорт" />
        <GlassSegmentedControl
          options={[...SPORTS]}
          value={form.mainSport}
          onChange={(value) => update('mainSport', value)}
        />

        <SectionTitle title="Пульс" />
        <ContentCard style={styles.formCard}>
          <NumberField label="Максимальный пульс" value={form.maxHeartRate} suffix="уд/мин" onChange={(value) => update('maxHeartRate', value)} />
          <NumberField label="Пульс покоя" value={form.restingHeartRate} suffix="уд/мин" onChange={(value) => update('restingHeartRate', value)} last />
        </ContentCard>

        <SectionTitle title="Порог и цели" />
        <ContentCard style={styles.formCard}>
          <NumberField label="Пороговый темп" value={form.thresholdPace} suffix="/км" onChange={(value) => update('thresholdPace', value)} keyboard="numbers-and-punctuation" />
          <NumberField label="Недельный объём" value={form.targetWeeklyKm} suffix="км" onChange={(value) => update('targetWeeklyKm', value)} />
          <NumberField label="FTP велосипеда" value={form.cyclingFTP} suffix="Вт" onChange={(value) => update('cyclingFTP', value)} last />
        </ContentCard>

        {message && <Text style={styles.successText}>{message}</Text>}
        {error && <Text style={styles.errorText}>{error}</Text>}

        <GlassButton
          label="Сохранить настройки"
          icon={<Save color={Colors.accentPrimary} size={20} />}
          onPress={save}
          prominent
          style={styles.saveButton}
        />
      </ScreenScrollView>
    </KeyboardAvoidingView>
  );
}

function NumberField({
  label,
  value,
  suffix,
  onChange,
  keyboard = 'decimal-pad',
  last = false,
}: {
  label: string;
  value: string;
  suffix: string;
  onChange: (value: string) => void;
  keyboard?: 'decimal-pad' | 'numbers-and-punctuation';
  last?: boolean;
}) {
  return (
    <View style={[styles.fieldRow, !last && styles.fieldDivider]}>
      <View style={styles.fieldLabelWrap}>
        <Text style={styles.fieldLabel}>{label}</Text>
        <Pencil color={Colors.textMuted} size={13} />
      </View>
      <View style={styles.fieldInputWrap}>
        <TextInput
          value={value}
          onChangeText={onChange}
          keyboardType={keyboard}
          style={styles.input}
          selectionColor={Colors.accentPrimary}
          accessibilityLabel={label}
        />
        <Text style={styles.suffix}>{suffix}</Text>
      </View>
    </View>
  );
}

function toForm(settings: UserSettings): SettingsForm {
  const pace = formatPace(settings.runningThresholdPaceSecondsPerKm).split(' ')[0];
  return {
    maxHeartRate: String(Math.round(settings.maxHeartRate)),
    restingHeartRate: String(Math.round(settings.restingHeartRate)),
    thresholdPace: pace,
    targetWeeklyKm: String(settings.targetWeeklyDistanceMeters / 1_000),
    cyclingFTP: String(Math.round(settings.cyclingFTP)),
    mainSport: settings.mainSport,
  };
}

function parsePositive(value: string): number {
  const parsed = Number(value.replace(',', '.'));
  if (!Number.isFinite(parsed) || parsed <= 0) throw new Error('Проверьте числовые значения.');
  return parsed;
}

function parsePace(value: string): number {
  const parts = value.trim().split(':');
  if (parts.length === 2) {
    const minutes = Number(parts[0]);
    const seconds = Number(parts[1]);
    if (Number.isInteger(minutes) && Number.isInteger(seconds) && minutes >= 0 && seconds >= 0 && seconds < 60) {
      const total = minutes * 60 + seconds;
      if (total > 0) return total;
    }
  }
  return parsePositive(value);
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: Spacing.xl },
  syncCard: { padding: Spacing.md },
  syncHeader: { flexDirection: 'row', alignItems: 'center' },
  providerIcon: { width: 48, height: 48, borderRadius: Radii.small, backgroundColor: Colors.surfaceRaised, alignItems: 'center', justifyContent: 'center' },
  syncText: { flex: 1, marginLeft: Spacing.sm },
  syncTitle: { ...Typography.headline },
  syncSubtitle: { ...Typography.caption, color: Colors.textSecondary, marginTop: 4 },
  connectButton: { marginTop: Spacing.md },
  providerNote: { ...Typography.caption, textAlign: 'center', marginTop: Spacing.xs },
  formCard: { paddingHorizontal: Spacing.md },
  fieldRow: { minHeight: 72, flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  fieldDivider: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.divider },
  fieldLabelWrap: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 6 },
  fieldLabel: { ...Typography.subheadline, color: Colors.textPrimary, flexShrink: 1 },
  fieldInputWrap: { minHeight: 44, minWidth: 118, flexDirection: 'row', alignItems: 'center', justifyContent: 'flex-end', borderRadius: Radii.small, backgroundColor: Colors.surfaceRaised, paddingRight: 10 },
  input: { minWidth: 58, height: 44, color: Colors.textPrimary, fontSize: 18, fontWeight: '800', fontVariant: ['tabular-nums'], textAlign: 'right', paddingHorizontal: 8 },
  suffix: { ...Typography.caption, color: Colors.textSecondary },
  successText: { ...Typography.body, color: Colors.accentPrimary, marginTop: Spacing.md },
  errorText: { ...Typography.body, color: Colors.danger, marginTop: Spacing.md },
  saveButton: { marginTop: Spacing.xl },
});
