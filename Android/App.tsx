import React, { useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { DarkTheme, NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { Activity, CircleUserRound, LayoutGrid, Map, Trophy } from 'lucide-react-native';
import { DashboardScreen } from './src/Screens/DashboardScreen';
import { FormScreen } from './src/Screens/FormScreen';
import { ActivityDetailScreen } from './src/Screens/ActivityDetailScreen';
import { ActivitiesScreen } from './src/Screens/ActivitiesScreen';
import { ProfileScreen } from './src/Screens/ProfileScreen';
import { RecordsScreen } from './src/Screens/RecordsScreen';
import { RoutesScreen } from './src/Screens/RoutesScreen';
import { AccessibilityProvider } from './src/DesignSystem/Accessibility';
import { AppBackdrop } from './src/DesignSystem/AppBackdrop';
import { Colors } from './src/DesignSystem/Colors';
import { Spacing } from './src/DesignSystem/DesignTokens';
import { TabBarStateProvider } from './src/DesignSystem/TabBarState';
import { Typography } from './src/DesignSystem/Typography';
import { initDatabase } from './src/Database/database';
import type { RootStackParamList, RootTabParamList } from './src/Navigation/types';
import { FloatingTabBar } from './src/Navigation/FloatingTabBar';

const Tab = createBottomTabNavigator<RootTabParamList>();
const Stack = createNativeStackNavigator<RootStackParamList>();

const navigationTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: Colors.accentPrimary,
    background: 'transparent',
    card: Colors.surface,
    text: Colors.textPrimary,
    border: Colors.divider,
    notification: Colors.ruby,
  },
};

function TabNavigator() {
  return (
    <Tab.Navigator
      tabBar={(props) => <FloatingTabBar {...props} />}
      screenOptions={{ headerShown: false, sceneStyle: { backgroundColor: 'transparent' } }}
    >
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{
          title: 'Главная',
          tabBarIcon: ({ color, size }) => <LayoutGrid color={color} size={size} strokeWidth={2} />,
        }}
      />
      <Tab.Screen
        name="Form"
        component={FormScreen}
        options={{
          title: 'Форма',
          tabBarIcon: ({ color, size }) => <Activity color={color} size={size} strokeWidth={2} />,
        }}
      />
      <Tab.Screen
        name="Records"
        component={RecordsScreen}
        options={{
          title: 'Рекорды',
          tabBarIcon: ({ color, size }) => <Trophy color={color} size={size} strokeWidth={2} />,
        }}
      />
      <Tab.Screen
        name="Routes"
        component={RoutesScreen}
        options={{
          title: 'Карта',
          tabBarIcon: ({ color, size }) => <Map color={color} size={size} strokeWidth={2} />,
        }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{
          title: 'Профиль',
          tabBarIcon: ({ color, size }) => <CircleUserRound color={color} size={size} strokeWidth={2} />,
        }}
      />
    </Tab.Navigator>
  );
}

function AppContent() {
  const [isReady, setIsReady] = useState(false);
  const [startupError, setStartupError] = useState<string | null>(null);

  useEffect(() => {
    try {
      initDatabase();
    } catch (error) {
      setStartupError(error instanceof Error ? error.message : 'Не удалось запустить приложение.');
    } finally {
      setIsReady(true);
    }
  }, []);

  if (!isReady) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={Colors.accentPrimary} size="large" />
        <Text style={styles.statusText}>Загрузка локальных данных…</Text>
      </View>
    );
  }

  if (startupError) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorTitle}>Ошибка запуска</Text>
        <Text style={styles.statusText}>{startupError}</Text>
      </View>
    );
  }

  return (
    <NavigationContainer theme={navigationTheme}>
      <Stack.Navigator
        screenOptions={{
          presentation: 'card',
          contentStyle: { backgroundColor: 'transparent' },
          headerStyle: { backgroundColor: Colors.surface },
          headerTintColor: Colors.textPrimary,
          headerShadowVisible: false,
        }}
      >
        <Stack.Screen name="Root" component={TabNavigator} options={{ headerShown: false }} />
        <Stack.Screen name="Activities" component={ActivitiesScreen} options={{ title: 'Все тренировки' }} />
        <Stack.Screen name="ActivityDetail" component={ActivityDetailScreen} options={{ title: 'Детали тренировки' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <AccessibilityProvider>
        <AppBackdrop>
          <TabBarStateProvider>
            <StatusBar style="light" />
            <AppContent />
          </TabBarStateProvider>
        </AppBackdrop>
      </AccessibilityProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: Spacing.md, padding: Spacing.xl },
  errorTitle: { ...Typography.title, color: Colors.danger },
  statusText: { ...Typography.body, textAlign: 'center' },
});
