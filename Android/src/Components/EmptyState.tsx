import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { LucideIcon } from 'lucide-react-native';
import { Colors } from '../DesignSystem/Colors';
import { Radii, Spacing } from '../DesignSystem/DesignTokens';
import { GlassSurface } from '../DesignSystem/GlassSurface';
import { Typography } from '../DesignSystem/Typography';
import { GlassButton } from './GlassButton';

interface Props {
  icon: LucideIcon;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
  compact?: boolean;
}

export function EmptyState({ icon: Icon, title, description, actionLabel, onAction, compact = false }: Props) {
  return (
    <View style={[styles.container, compact && styles.compact]}>
      <GlassSurface radius={Radii.pill} style={styles.iconCircle}>
        <Icon color={Colors.accentPrimary} size={compact ? 30 : 42} strokeWidth={1.7} />
      </GlassSurface>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>
      {actionLabel ? <GlassButton label={actionLabel} onPress={onAction} prominent style={styles.action} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', paddingHorizontal: Spacing.xl, paddingVertical: Spacing.xxl },
  compact: { paddingVertical: Spacing.xl },
  iconCircle: { width: 76, height: 76, alignItems: 'center', justifyContent: 'center' },
  title: { ...Typography.headline, marginTop: Spacing.md, textAlign: 'center' },
  description: { ...Typography.subheadline, marginTop: Spacing.xs, textAlign: 'center', maxWidth: 300 },
  action: { alignSelf: 'stretch', marginTop: Spacing.lg },
});
