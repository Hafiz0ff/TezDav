import {
  getGrantedPermissions,
  initialize,
  requestPermission,
  readRecords,
} from 'react-native-health-connect';

const stepsPermission = { accessType: 'read', recordType: 'Steps' } as const;

export type HealthConnectStatus =
  | 'ready'
  | 'permission-required'
  | 'unavailable'
  | 'error';

export const getHealthConnectStatus = async (): Promise<HealthConnectStatus> => {
  try {
    const isInitialized = await initialize();
    if (!isInitialized) {
      return 'unavailable';
    }

    const grantedPermissions = await getGrantedPermissions();
    return grantedPermissions.some(
      (permission) =>
        permission.accessType === stepsPermission.accessType &&
        permission.recordType === stepsPermission.recordType,
    )
      ? 'ready'
      : 'permission-required';
  } catch {
    return 'error';
  }
};

export const requestHealthConnectAccess = async (): Promise<boolean> => {
  try {
    const isInitialized = await initialize();
    if (!isInitialized) return false;

    const grantedPermissions = await requestPermission([stepsPermission]);
    return grantedPermissions.some(
      (permission) =>
        permission.accessType === stepsPermission.accessType &&
        permission.recordType === stepsPermission.recordType,
    );
  } catch {
    return false;
  }
};

export const fetchTodaySteps = async (): Promise<number | null> => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const result = await readRecords('Steps', {
      timeRangeFilter: {
        operator: 'between',
        startTime: startOfDay.toISOString(),
        endTime: endOfDay.toISOString(),
      },
    });

    let totalSteps = 0;
    for (const record of result.records) {
      totalSteps += record.count;
    }

    return totalSteps;
  } catch {
    return null;
  }
};
