import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Colors } from '../DesignSystem/Colors';
import { Radii, Spacing } from '../DesignSystem/DesignTokens';
import { Typography } from '../DesignSystem/Typography';

export function RecordRow({ label, status, value, isFirst = false }: { label: string; status: string; value?: string; isFirst?: boolean }) {
  return (
    <View style={[styles.row, !isFirst && styles.divider]}>
      <View style={styles.text}>
        <Text style={styles.label}>{label}</Text>
        <Text style={styles.status} numberOfLines={1}>{status}</Text>
      </View>
      {value ? (
        <View style={styles.valuePill}>
          <Text style={styles.value}>{value}</Text>
        </View>
      ) : (
        <View style={styles.ghostPill} accessibilityLabel="Рекорд пока не рассчитан">
          <View style={styles.ghostDot} />
          <View style={styles.ghostLine} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { minHeight: 76, flexDirection: 'row', alignItems: 'center', paddingVertical: Spacing.sm },
  divider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.divider },
  text: { flex: 1, minWidth: 0, marginRight: Spacing.md },
  label: { ...Typography.headline, fontSize: 18 },
  status: { ...Typography.caption, marginTop: Spacing.xxs },
  valuePill: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: Radii.pill, backgroundColor: Colors.accentTint },
  value: { ...Typography.metric, fontSize: 18, lineHeight: 22, color: Colors.accentPrimary },
  ghostPill: {
    width: 72,
    height: 32,
    borderRadius: Radii.pill,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: 'rgba(167,171,176,0.36)',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  ghostDot: { width: 4, height: 4, borderRadius: 2, backgroundColor: Colors.textMuted },
  ghostLine: { width: 30, height: 3, borderRadius: 2, backgroundColor: Colors.textMuted },
});
