import React, { useEffect, useRef } from 'react';
import { Animated, Pressable, StyleSheet, Text, View } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Haptics from 'expo-haptics';
import { useAccessibilityPreferences } from '../DesignSystem/Accessibility';
import { Colors } from '../DesignSystem/Colors';
import { Motion, Radii, Sizes } from '../DesignSystem/DesignTokens';
import { GlassSurface } from '../DesignSystem/GlassSurface';
import { useTabBarState } from '../DesignSystem/TabBarState';
import { Typography } from '../DesignSystem/Typography';

export function FloatingTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const { minimized, expand } = useTabBarState();
  const { reduceMotion } = useAccessibilityPreferences();
  const progress = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const toValue = minimized ? 1 : 0;
    const animation = reduceMotion
      ? Animated.timing(progress, { toValue, duration: Motion.quick, useNativeDriver: false })
      : Animated.spring(progress, { toValue, ...Motion.spring, useNativeDriver: false });
    animation.start();
  }, [minimized, progress, reduceMotion]);

  const height = progress.interpolate({
    inputRange: [0, 1],
    outputRange: [Sizes.tabBarExpanded, Sizes.tabBarCompact],
  });
  const labelOpacity = progress.interpolate({ inputRange: [0, 0.75], outputRange: [1, 0], extrapolate: 'clamp' });
  const labelScale = progress.interpolate({ inputRange: [0, 1], outputRange: [1, 0.82] });

  return (
    <View pointerEvents="box-none" style={[styles.wrapper, { bottom: Math.max(10, insets.bottom) }]}>
      <Animated.View style={[styles.animatedBar, { height }]}>
        <GlassSurface radius={Radii.large} style={styles.glass}>
          {state.routes.map((route, index) => {
            const { options } = descriptors[route.key];
            const focused = state.index === index;
            const color = focused ? Colors.accentPrimary : Colors.textMuted;
            const label = typeof options.tabBarLabel === 'string'
              ? options.tabBarLabel
              : options.title ?? route.name;
            const onPress = () => {
              const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
              if (!focused && !event.defaultPrevented) {
                void Haptics.selectionAsync();
                navigation.navigate(route.name, route.params);
              }
              expand();
            };
            return (
              <Pressable
                key={route.key}
                onPress={onPress}
                onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
                accessibilityRole="tab"
                accessibilityState={{ selected: focused }}
                accessibilityLabel={options.tabBarAccessibilityLabel ?? label}
                style={({ pressed }) => [styles.item, focused && styles.activeItem, pressed && styles.pressed]}
              >
                {options.tabBarIcon?.({ focused, color, size: minimized ? 21 : 23 })}
                <Animated.Text
                  numberOfLines={1}
                  style={[styles.label, { color, opacity: labelOpacity, transform: [{ scale: labelScale }] }]}
                >
                  {label}
                </Animated.Text>
              </Pressable>
            );
          })}
        </GlassSurface>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: { position: 'absolute', left: 12, right: 12 },
  animatedBar: { width: '100%' },
  glass: { flex: 1, flexDirection: 'row', padding: 5, gap: 2 },
  item: { flex: 1, minWidth: 0, borderRadius: 22, alignItems: 'center', justifyContent: 'center', gap: 2 },
  activeItem: { backgroundColor: Colors.accentTint },
  pressed: { opacity: 0.72 },
  label: { ...Typography.caption, fontSize: 10, lineHeight: 13, fontWeight: '700' },
});
