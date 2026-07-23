import React, { useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { MapPin, Route } from 'lucide-react-native';
import Svg, { Circle, Path } from 'react-native-svg';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Activity, getActivities } from '../Database/database';
import { ActivityRow } from '../Components/ActivityRow';
import { EmptyState } from '../Components/EmptyState';
import { SectionTitle } from '../Components/SectionTitle';
import { Colors } from '../DesignSystem/Colors';
import { ContentCard } from '../DesignSystem/ContentCard';
import { Spacing } from '../DesignSystem/DesignTokens';
import { Typography } from '../DesignSystem/Typography';
import type { RootStackParamList } from '../Navigation/types';

export function RoutesScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [routes, setRoutes] = useState<Activity[]>([]);

  useFocusEffect(
    useCallback(() => {
      setRoutes(getActivities().filter((activity) => Boolean(activity.encodedPolyline)));
    }, []),
  );

  return (
    <View style={styles.container}>
      <MapCanvas />
      <SafeAreaView style={styles.safeArea} edges={['top']} pointerEvents="box-none">
        <View style={styles.header}>
          <Text style={Typography.largeTitle}>Карта</Text>
          <Text style={styles.subtitle}>Маршруты из локальной истории</Text>
        </View>

        {routes.length === 0 ? (
          <View style={styles.emptyPosition}>
            <ContentCard>
              <EmptyState
                icon={MapPin}
                title="GPS-маршрутов пока нет"
                description="После импорта полилиний маршруты появятся поверх этой карты."
              />
            </ContentCard>
          </View>
        ) : (
          <View style={styles.sheet}>
            <View style={styles.handle} />
            <SectionTitle title={`${routes.length} ${routeWord(routes.length)}`} />
            <ContentCard>
              {routes.slice(0, 4).map((activity) => (
                <ActivityRow
                  key={activity.id}
                  activity={activity}
                  onPress={() => navigation.navigate('ActivityDetail', { activity })}
                />
              ))}
            </ContentCard>
          </View>
        )}
      </SafeAreaView>
    </View>
  );
}

function MapCanvas() {
  return (
    <View style={StyleSheet.absoluteFill} accessibilityElementsHidden>
      <Svg width="100%" height="100%" viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice">
        <Path d="M-30 100 C70 65 115 140 210 95 S360 38 440 74" fill="none" stroke={Colors.mapLine} strokeWidth="30" />
        <Path d="M-20 250 C75 310 105 190 210 260 S350 360 430 290" fill="none" stroke={Colors.mapLine} strokeWidth="22" />
        <Path d="M60 -30 C120 120 55 230 145 350 S215 585 95 880" fill="none" stroke="#15211E" strokeWidth="18" />
        <Path d="M300 -20 C260 130 360 220 290 365 S245 615 355 880" fill="none" stroke="#131D1A" strokeWidth="26" />
        <Path d="M-20 620 C100 560 145 675 230 615 S350 545 420 610" fill="none" stroke="#17231F" strokeWidth="20" />
        <Path d="M34 106 C95 82 126 135 205 104 S325 63 386 81" fill="none" stroke="#24352F" strokeWidth="2" />
        <Path d="M28 255 C84 287 123 223 207 265 S315 327 379 297" fill="none" stroke="#24352F" strokeWidth="2" />
        <Path d="M65 0 C112 130 73 236 151 351 S205 563 108 844" fill="none" stroke="#294039" strokeWidth="2" />
        <Circle cx="151" cy="351" r="6" fill={Colors.accentPrimary} fillOpacity="0.5" />
        <Circle cx="151" cy="351" r="18" fill={Colors.accentPrimary} fillOpacity="0.08" />
      </Svg>
      <View style={styles.mapShade} />
      <View style={styles.routeBadge}>
        <Route color={Colors.accentPrimary} size={18} />
      </View>
    </View>
  );
}

function routeWord(count: number) {
  const mod10 = count % 10;
  const mod100 = count % 100;
  if (mod10 === 1 && mod100 !== 11) return 'маршрут';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'маршрута';
  return 'маршрутов';
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.backgroundDeep },
  safeArea: { flex: 1 },
  header: { paddingHorizontal: Spacing.screen, paddingTop: Spacing.sm },
  subtitle: { ...Typography.subheadline, marginTop: Spacing.xxs },
  emptyPosition: { flex: 1, justifyContent: 'center', paddingHorizontal: Spacing.screen, paddingBottom: 86 },
  sheet: { marginTop: 'auto', paddingHorizontal: Spacing.screen, paddingBottom: 112, maxHeight: '62%', backgroundColor: 'rgba(8,9,11,0.82)', borderTopLeftRadius: 30, borderTopRightRadius: 30 },
  handle: { width: 38, height: 5, borderRadius: 3, backgroundColor: Colors.textMuted, alignSelf: 'center', marginTop: Spacing.sm, marginBottom: -Spacing.sm },
  mapShade: { position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, backgroundColor: 'rgba(3,6,5,0.28)' },
  routeBadge: { position: 'absolute', right: 22, top: '42%', width: 46, height: 46, borderRadius: 23, alignItems: 'center', justifyContent: 'center', backgroundColor: Colors.surfaceRaised, borderWidth: 1, borderColor: Colors.glassBorder },
});
