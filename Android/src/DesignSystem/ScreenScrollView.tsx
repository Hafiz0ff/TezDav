import React, { useRef } from 'react';
import {
  Animated,
  ScrollViewProps,
  StyleProp,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from './Colors';
import { Sizes, Spacing } from './DesignTokens';
import { GlassSurface } from './GlassSurface';
import { Typography } from './Typography';
import { useTabBarState } from './TabBarState';

interface Props extends Omit<ScrollViewProps, 'contentContainerStyle'> {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  contentContainerStyle?: StyleProp<ViewStyle>;
}

export function ScreenScrollView({ title, subtitle, children, contentContainerStyle, ...props }: Props) {
  const insets = useSafeAreaInsets();
  const scrollY = useRef(new Animated.Value(0)).current;
  const { onScroll } = useTabBarState();
  const inlineOpacity = scrollY.interpolate({
    inputRange: [24, 68],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });
  const titleScale = scrollY.interpolate({
    inputRange: [-20, 0, 64],
    outputRange: [1.04, 1, 0.92],
    extrapolate: 'clamp',
  });

  return (
    <View style={styles.root}>
      <Animated.ScrollView
        {...props}
        onScroll={Animated.event(
          [{ nativeEvent: { contentOffset: { y: scrollY } } }],
          { useNativeDriver: true, listener: onScroll },
        )}
        scrollEventThrottle={16}
        contentContainerStyle={[styles.content, { paddingTop: insets.top + Spacing.sm }, contentContainerStyle]}
        showsVerticalScrollIndicator={false}
      >
        <Animated.View style={[styles.heroHeader, { transform: [{ scale: titleScale }] }]}>
          <Text style={Typography.largeTitle}>{title}</Text>
          {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
        </Animated.View>
        {children}
      </Animated.ScrollView>

      <Animated.View pointerEvents="none" style={[styles.inlineHeader, { paddingTop: insets.top, opacity: inlineOpacity }]}>
        <GlassSurface radius={0} style={styles.inlineGlass}>
          <Text style={styles.inlineTitle}>{title}</Text>
        </GlassSurface>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: 'transparent' },
  content: {
    paddingHorizontal: Spacing.screen,
    paddingBottom: Sizes.screenBottomInset,
  },
  heroHeader: { transformOrigin: 'left top', marginBottom: Spacing.xl },
  subtitle: { ...Typography.subheadline, marginTop: Spacing.xxs },
  inlineHeader: { position: 'absolute', left: 0, right: 0, top: 0 },
  inlineGlass: {
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    borderLeftWidth: 0,
    borderRightWidth: 0,
    borderTopWidth: 0,
    backgroundColor: Colors.backgroundMain,
  },
  inlineTitle: { ...Typography.headline, fontSize: 16 },
});
