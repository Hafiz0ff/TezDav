import React from 'react';
import { StyleProp, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { Colors } from '../DesignSystem/Colors';
import { Typography } from '../DesignSystem/Typography';

interface Props {
  label: string;
  value: string;
  color?: string;
  style?: StyleProp<ViewStyle>;
}

export function MetricTile({ label, value, color = Colors.textPrimary, style }: Props) {
  return (
    <View style={[styles.container, style]}>
      <Text style={styles.label} numberOfLines={2}>{label}</Text>
      <Text style={[styles.value, { color }]} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.72}>
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, minWidth: 76 },
  label: { ...Typography.caption, minHeight: 34, marginBottom: 4 },
  value: { ...Typography.metric },
});
