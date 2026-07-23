import React from 'react';
import { StyleProp, StyleSheet, View, ViewStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Colors } from './Colors';
import { Radii } from './DesignTokens';
import { useAccessibilityPreferences } from './Accessibility';

interface Props {
  children?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  radius?: number;
  tint?: 'neutral' | 'emerald' | 'ruby';
}

export function GlassSurface({ children, style, radius = Radii.control, tint = 'neutral' }: Props) {
  const { reduceTransparency } = useAccessibilityPreferences();
  const tintColor = tint === 'emerald' ? Colors.accentTint : tint === 'ruby' ? Colors.rubyTint : Colors.glassBackground;
  return (
    <View style={[styles.container, { borderRadius: radius }, reduceTransparency && styles.opaque, style]}>
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: tintColor }]} />
      <LinearGradient
        pointerEvents="none"
        colors={[Colors.glassHighlight, 'rgba(255,255,255,0.02)', 'transparent']}
        start={{ x: 0.05, y: 0 }}
        end={{ x: 0.85, y: 1 }}
        style={StyleSheet.absoluteFill}
      />
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.glassBorder,
    backgroundColor: 'rgba(24,27,30,0.84)',
  },
  opaque: { backgroundColor: Colors.glassFallback },
});
