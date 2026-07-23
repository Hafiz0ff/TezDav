import React from 'react';
import { Pressable, StyleProp, StyleSheet, Text, ViewStyle } from 'react-native';
import * as Haptics from 'expo-haptics';
import { Colors } from '../DesignSystem/Colors';
import { Radii, Sizes, Spacing } from '../DesignSystem/DesignTokens';
import { GlassSurface } from '../DesignSystem/GlassSurface';
import { Typography } from '../DesignSystem/Typography';

interface Props {
  label: string;
  onPress?: () => void;
  icon?: React.ReactNode;
  prominent?: boolean;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function GlassButton({ label, onPress, icon, prominent = false, disabled = false, style }: Props) {
  const handlePress = () => {
    if (disabled) return;
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onPress?.();
  };
  return (
    <Pressable
      onPress={handlePress}
      disabled={disabled}
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      style={({ pressed }) => [styles.pressable, pressed && styles.pressed, disabled && styles.disabled, style]}
    >
      <GlassSurface tint={prominent ? 'emerald' : 'neutral'} radius={Radii.pill} style={styles.surface}>
        {icon}
        <Text style={[styles.label, prominent && styles.prominentLabel]}>{label}</Text>
      </GlassSurface>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  pressable: { minHeight: Sizes.minimumTap },
  surface: {
    minHeight: Sizes.minimumTap,
    paddingHorizontal: Spacing.lg,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.xs,
  },
  label: { ...Typography.headline, fontSize: 15 },
  prominentLabel: { color: Colors.textPrimary },
  pressed: { transform: [{ scale: 0.98 }], opacity: 0.88 },
  disabled: { opacity: 0.55 },
});
