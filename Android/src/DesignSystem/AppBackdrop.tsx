import React from 'react';
import { StyleSheet, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Colors } from './Colors';

export function AppBackdrop({ children }: { children: React.ReactNode }) {
  return (
    <View style={styles.root}>
        <View style={StyleSheet.absoluteFill}>
          <LinearGradient
            colors={[Colors.backgroundMain, Colors.backgroundDeep, Colors.backgroundMain]}
            locations={[0, 0.56, 1]}
            style={StyleSheet.absoluteFill}
          />
          <View style={[styles.glow, styles.emeraldGlow]} />
          <View style={[styles.glow, styles.rubyGlow]} />
          <LinearGradient
            colors={['rgba(255,255,255,0.018)', 'transparent', 'rgba(29,191,136,0.02)']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={StyleSheet.absoluteFill}
          />
        </View>
        {children}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.backgroundMain, overflow: 'hidden' },
  glow: { position: 'absolute', borderRadius: 999 },
  emeraldGlow: {
    width: 420,
    height: 420,
    top: -170,
    right: -210,
    backgroundColor: Colors.emeraldAuroraStart,
  },
  rubyGlow: {
    width: 360,
    height: 360,
    bottom: -190,
    left: -210,
    backgroundColor: Colors.rubyAurora,
  },
});
