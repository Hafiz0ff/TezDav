import React, { useEffect, useRef, useState } from 'react';
import { Animated, LayoutChangeEvent, Pressable, StyleSheet, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { useAccessibilityPreferences } from '../DesignSystem/Accessibility';
import { Colors } from '../DesignSystem/Colors';
import { Motion, Radii, Sizes, Spacing } from '../DesignSystem/DesignTokens';
import { GlassSurface } from '../DesignSystem/GlassSurface';
import { Typography } from '../DesignSystem/Typography';

interface Option<T extends string | number> { value: T; label: string }

export function GlassSegmentedControl<T extends string | number>({
  options,
  value,
  onChange,
}: {
  options: Array<Option<T>>;
  value: T;
  onChange: (value: T) => void;
}) {
  const [width, setWidth] = useState(0);
  const position = useRef(new Animated.Value(Math.max(0, options.findIndex((option) => option.value === value)))).current;
  const { reduceMotion } = useAccessibilityPreferences();
  const activeIndex = Math.max(0, options.findIndex((option) => option.value === value));

  useEffect(() => {
    const animation = reduceMotion
      ? Animated.timing(position, { toValue: activeIndex, duration: Motion.quick, useNativeDriver: true })
      : Animated.spring(position, { toValue: activeIndex, ...Motion.spring, useNativeDriver: true });
    animation.start();
  }, [activeIndex, position, reduceMotion]);

  const segmentWidth = width > 0 ? (width - 6) / options.length : 0;
  const onLayout = (event: LayoutChangeEvent) => setWidth(event.nativeEvent.layout.width);

  return (
    <GlassSurface radius={Radii.pill} style={styles.container}>
      <View onLayout={onLayout} style={styles.inner} accessibilityRole="tablist">
        {segmentWidth > 0 && (
          <Animated.View
            pointerEvents="none"
            style={[
              styles.indicator,
              {
                width: segmentWidth,
                transform: [{ translateX: Animated.multiply(position, segmentWidth) }],
              },
            ]}
          />
        )}
        {options.map((option) => {
          const selected = option.value === value;
          return (
            <Pressable
              key={String(option.value)}
              onPress={() => {
                if (!selected) void Haptics.selectionAsync();
                onChange(option.value);
              }}
              style={styles.segment}
              accessibilityRole="tab"
              accessibilityState={{ selected }}
            >
              <Text style={[styles.label, selected && styles.selectedLabel]}>{option.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </GlassSurface>
  );
}

const styles = StyleSheet.create({
  container: { height: Sizes.minimumTap, padding: 3 },
  inner: { flex: 1, flexDirection: 'row' },
  indicator: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    borderRadius: Radii.pill,
    borderWidth: 1,
    borderColor: 'rgba(29,191,136,0.34)',
    backgroundColor: Colors.accentTintStrong,
  },
  segment: { flex: 1, minWidth: 0, alignItems: 'center', justifyContent: 'center', paddingHorizontal: Spacing.xs },
  label: { ...Typography.caption, color: Colors.textSecondary },
  selectedLabel: { color: Colors.textPrimary, fontWeight: '700' },
});
