import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Colors } from '../DesignSystem/Colors';
import { Spacing } from '../DesignSystem/DesignTokens';
import { Typography } from '../DesignSystem/Typography';

export function SectionTitle({ title, accessory }: { title: string; accessory?: React.ReactNode }) {
  return (
    <View style={styles.row}>
      <Text style={styles.title}>{title}</Text>
      {accessory}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 34,
    marginTop: Spacing.xl,
    marginBottom: Spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: { ...Typography.title, color: Colors.textPrimary, fontSize: 20, lineHeight: 26 },
});
