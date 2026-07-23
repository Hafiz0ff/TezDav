import React, { useCallback, useState } from 'react';
import { FlatList, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Activity, getActivities } from '../Database/database';
import { ActivityRow } from '../Components/ActivityRow';
import { Colors } from '../DesignSystem/Colors';
import { Typography } from '../DesignSystem/Typography';
import type { RootStackParamList } from '../Navigation/types';

export function ActivitiesScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [activities, setActivities] = useState<Activity[]>([]);

  useFocusEffect(
    useCallback(() => {
      setActivities(getActivities());
    }, []),
  );

  return (
    <SafeAreaView style={styles.container} edges={['bottom']}>
      <FlatList
        data={activities}
        keyExtractor={(activity) => activity.id}
        contentContainerStyle={activities.length === 0 ? styles.emptyContainer : styles.listContent}
        renderItem={({ item }) => (
          <ActivityRow
            activity={item}
            onPress={() => navigation.navigate('ActivityDetail', { activity: item })}
          />
        )}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
        ListEmptyComponent={
          <View>
            <Text style={styles.emptyTitle}>Журнал пуст</Text>
            <Text style={styles.emptyText}>После импорта здесь появится полная история тренировок.</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.backgroundMain },
  listContent: { paddingVertical: 8 },
  separator: { height: 1, marginHorizontal: 18, backgroundColor: Colors.glassBorder },
  emptyContainer: { flexGrow: 1, justifyContent: 'center', padding: 28 },
  emptyTitle: { ...Typography.title, fontSize: 22, marginBottom: 8 },
  emptyText: { ...Typography.body },
});
