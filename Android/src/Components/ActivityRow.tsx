import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { ChevronRight } from 'lucide-react-native';
import type { Activity } from '../Database/database';
import { Colors } from '../DesignSystem/Colors';
import { Typography } from '../DesignSystem/Typography';
import { formatDistance, formatDuration, sportName } from '../Utils/formatters';

interface Props {
  activity: Activity;
  onPress: () => void;
}

export function ActivityRow({ activity, onPress }: Props) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.container, pressed && styles.pressed]}
      accessibilityRole="button"
      accessibilityLabel={`Открыть тренировку ${activity.title}`}
    >
      <View style={styles.textColumn}>
        <Text style={styles.title} numberOfLines={1}>{activity.title}</Text>
        <Text style={styles.subtitle}>
          {sportName(activity.type)} · {new Date(activity.date).toLocaleDateString('ru-RU')}
        </Text>
        <Text style={styles.metrics}>
          {formatDistance(activity.distance)} · {formatDuration(activity.duration)} · TSS {Math.round(activity.tss)}
        </Text>
      </View>
      <ChevronRight color={Colors.textMuted} size={20} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    minHeight: 84,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 13,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.glassBorder,
  },
  pressed: {
    backgroundColor: 'rgba(255,255,255,0.05)',
  },
  textColumn: {
    flex: 1,
    marginRight: 12,
  },
  title: {
    ...Typography.title,
    fontSize: 17,
  },
  subtitle: {
    ...Typography.caption,
    color: Colors.textSecondary,
    marginTop: 4,
  },
  metrics: {
    ...Typography.caption,
    color: Colors.accentPrimary,
    marginTop: 6,
  },
});
