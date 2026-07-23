import { Platform, TextStyle } from 'react-native';
import { Colors } from './Colors';

const displayFamily = Platform.select({ android: 'sans-serif', default: undefined });
const textFamily = Platform.select({ android: 'sans-serif', default: undefined });

export const Typography = {
  largeTitle: {
    fontFamily: displayFamily,
    fontSize: 34,
    lineHeight: 40,
    fontWeight: '800',
    letterSpacing: -0.8,
    color: Colors.textPrimary,
  } as TextStyle,
  title: {
    fontFamily: displayFamily,
    fontSize: 22,
    lineHeight: 28,
    fontWeight: '700',
    letterSpacing: -0.25,
    color: Colors.textPrimary,
  } as TextStyle,
  headline: {
    fontFamily: textFamily,
    fontSize: 17,
    lineHeight: 22,
    fontWeight: '700',
    color: Colors.textPrimary,
  } as TextStyle,
  body: {
    fontFamily: textFamily,
    fontSize: 16,
    lineHeight: 22,
    fontWeight: '400',
    color: Colors.textSecondary,
  } as TextStyle,
  subheadline: {
    fontFamily: textFamily,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '400',
    color: Colors.textSecondary,
  } as TextStyle,
  caption: {
    fontFamily: textFamily,
    fontSize: 13,
    lineHeight: 17,
    fontWeight: '500',
    color: Colors.textMuted,
  } as TextStyle,
  metricHero: {
    fontFamily: displayFamily,
    fontSize: 52,
    lineHeight: 58,
    fontWeight: '800',
    letterSpacing: -1.6,
    fontVariant: ['tabular-nums'],
    color: Colors.textPrimary,
  } as TextStyle,
  metricLarge: {
    fontFamily: displayFamily,
    fontSize: 28,
    lineHeight: 34,
    fontWeight: '800',
    letterSpacing: -0.45,
    fontVariant: ['tabular-nums'],
    color: Colors.textPrimary,
  } as TextStyle,
  metric: {
    fontFamily: displayFamily,
    fontSize: 22,
    lineHeight: 28,
    fontWeight: '800',
    letterSpacing: -0.25,
    fontVariant: ['tabular-nums'],
    color: Colors.textPrimary,
  } as TextStyle,
};
