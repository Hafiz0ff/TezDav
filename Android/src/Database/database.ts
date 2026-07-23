import * as SQLite from 'expo-sqlite';

export const db = SQLite.openDatabaseSync('tezdav.db');

const SCHEMA_VERSION = 2;

export interface Activity {
  id: string;
  title: string;
  type: string;
  distance: number;
  duration: number;
  date: string;
  tss: number;
  elevationGain: number;
  averageHeartRate: number | null;
  averagePower: number | null;
  averageCadence: number | null;
  averageSpeed: number | null;
  encodedPolyline: string | null;
  trimp: number;
  streamsImported: boolean;
  source: string;
}

export interface ActivityInput {
  id: string;
  title: string;
  type: string;
  distance: number;
  duration: number;
  date: string;
  tss: number;
  elevationGain?: number;
  averageHeartRate?: number | null;
  averagePower?: number | null;
  averageCadence?: number | null;
  averageSpeed?: number | null;
  encodedPolyline?: string | null;
  trimp?: number;
  streamsImported?: boolean;
  source?: string;
}

export interface ActivityStreamSample {
  activityId: string;
  offsetSeconds: number;
  distanceMeters?: number;
  heartRate?: number;
  cadence?: number;
  power?: number;
  speed?: number;
  elevation?: number;
  latitude?: number;
  longitude?: number;
}

export interface UserSettings {
  maxHeartRate: number;
  restingHeartRate: number;
  runningThresholdPaceSecondsPerKm: number;
  targetWeeklyDistanceMeters: number;
  cyclingFTP: number;
  mainSport: string;
}

export interface SyncState {
  provider: string;
  connected: boolean;
  athleteName: string | null;
  lastSyncedAt: string | null;
  lastError: string | null;
}

type ActivityRow = Omit<Activity, 'streamsImported'> & { streamsImported: number };
type SyncStateRow = Omit<SyncState, 'connected'> & { connected: number };

export const initDatabase = () => {
  db.execSync('PRAGMA journal_mode = WAL;');
  db.execSync('PRAGMA foreign_keys = ON;');

  db.withTransactionSync(() => {
    db.execSync(`
      CREATE TABLE IF NOT EXISTS activities (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        distance REAL NOT NULL,
        duration INTEGER NOT NULL,
        date TEXT NOT NULL,
        tss REAL NOT NULL,
        elevation_gain REAL NOT NULL DEFAULT 0,
        average_heart_rate REAL,
        average_power REAL,
        average_cadence REAL,
        average_speed REAL,
        encoded_polyline TEXT,
        trimp REAL NOT NULL DEFAULT 0,
        streams_imported INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'local'
      );
    `);

    ensureActivityColumns();

    db.execSync(`
      CREATE TABLE IF NOT EXISTS activity_stream_samples (
        activity_id TEXT NOT NULL,
        offset_seconds REAL NOT NULL,
        distance_meters REAL,
        heart_rate REAL,
        cadence REAL,
        power REAL,
        speed REAL,
        elevation REAL,
        latitude REAL,
        longitude REAL,
        PRIMARY KEY (activity_id, offset_seconds),
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS user_settings (
        key TEXT PRIMARY KEY NOT NULL,
        max_heart_rate REAL NOT NULL,
        resting_heart_rate REAL NOT NULL,
        running_threshold_pace REAL NOT NULL,
        target_weekly_distance REAL NOT NULL,
        cycling_ftp REAL NOT NULL,
        main_sport TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_state (
        provider TEXT PRIMARY KEY NOT NULL,
        connected INTEGER NOT NULL DEFAULT 0,
        athlete_name TEXT,
        last_synced_at TEXT,
        last_error TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_activities_date ON activities(date DESC);
      CREATE INDEX IF NOT EXISTS idx_streams_activity ON activity_stream_samples(activity_id, offset_seconds);

      INSERT OR IGNORE INTO user_settings (
        key, max_heart_rate, resting_heart_rate, running_threshold_pace,
        target_weekly_distance, cycling_ftp, main_sport
      ) VALUES ('default', 190, 60, 270, 50000, 250, 'Running');

      INSERT OR IGNORE INTO sync_state (provider, connected)
      VALUES ('strava', 0);

      PRAGMA user_version = ${SCHEMA_VERSION};
    `);
  });
};

export const insertActivity = (activity: ActivityInput) => {
  validateActivity(activity);
  db.runSync(
    `INSERT INTO activities (
       id, title, type, distance, duration, date, tss, elevation_gain,
       average_heart_rate, average_power, average_cadence, average_speed,
       encoded_polyline, trimp, streams_imported, source
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       title = excluded.title,
       type = excluded.type,
       distance = excluded.distance,
       duration = excluded.duration,
       date = excluded.date,
       tss = excluded.tss,
       elevation_gain = excluded.elevation_gain,
       average_heart_rate = excluded.average_heart_rate,
       average_power = excluded.average_power,
       average_cadence = excluded.average_cadence,
       average_speed = excluded.average_speed,
       encoded_polyline = excluded.encoded_polyline,
       trimp = excluded.trimp,
       streams_imported = excluded.streams_imported,
       source = excluded.source`,
    [
      activity.id,
      activity.title,
      activity.type,
      activity.distance,
      activity.duration,
      activity.date,
      activity.tss,
      activity.elevationGain ?? 0,
      activity.averageHeartRate ?? null,
      activity.averagePower ?? null,
      activity.averageCadence ?? null,
      activity.averageSpeed ?? null,
      activity.encodedPolyline ?? null,
      activity.trimp ?? 0,
      activity.streamsImported ? 1 : 0,
      activity.source ?? 'local',
    ],
  );
};

export const replaceActivityStreamSamples = (
  activityId: string,
  samples: ActivityStreamSample[],
) => {
  if (!activityId.trim()) throw new Error('Activity id is required.');
  const validSamples = samples.filter(
    (sample) => Number.isFinite(sample.offsetSeconds) && sample.offsetSeconds >= 0,
  );

  db.withTransactionSync(() => {
    db.runSync('DELETE FROM activity_stream_samples WHERE activity_id = ?', [activityId]);
    for (const sample of validSamples) {
      db.runSync(
        `INSERT INTO activity_stream_samples (
           activity_id, offset_seconds, distance_meters, heart_rate, cadence,
           power, speed, elevation, latitude, longitude
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          activityId,
          sample.offsetSeconds,
          finiteOrNull(sample.distanceMeters),
          finiteOrNull(sample.heartRate),
          finiteOrNull(sample.cadence),
          finiteOrNull(sample.power),
          finiteOrNull(sample.speed),
          finiteOrNull(sample.elevation),
          finiteOrNull(sample.latitude),
          finiteOrNull(sample.longitude),
        ],
      );
    }
    db.runSync('UPDATE activities SET streams_imported = ? WHERE id = ?', [
      validSamples.length > 0 ? 1 : 0,
      activityId,
    ]);
  });
};

export const getActivities = (): Activity[] => {
  const rows = db.getAllSync<ActivityRow>(ACTIVITY_SELECT);
  return rows.map(mapActivityRow);
};

export const getRecentActivities = (limit = 5): Activity[] => {
  const safeLimit = Math.max(1, Math.min(1000, Math.floor(limit)));
  const rows = db.getAllSync<ActivityRow>(`${ACTIVITY_SELECT} LIMIT ?`, [safeLimit]);
  return rows.map(mapActivityRow);
};

export const getActivityStreamSamples = (activityId: string): ActivityStreamSample[] => {
  return db.getAllSync<ActivityStreamSample>(
    `SELECT
       activity_id AS activityId,
       offset_seconds AS offsetSeconds,
       distance_meters AS distanceMeters,
       heart_rate AS heartRate,
       cadence,
       power,
       speed,
       elevation,
       latitude,
       longitude
     FROM activity_stream_samples
     WHERE activity_id = ?
     ORDER BY offset_seconds ASC`,
    [activityId],
  );
};

export const getUserSettings = (): UserSettings => {
  const settings = db.getFirstSync<UserSettings>(
    `SELECT
       max_heart_rate AS maxHeartRate,
       resting_heart_rate AS restingHeartRate,
       running_threshold_pace AS runningThresholdPaceSecondsPerKm,
       target_weekly_distance AS targetWeeklyDistanceMeters,
       cycling_ftp AS cyclingFTP,
       main_sport AS mainSport
     FROM user_settings
     WHERE key = 'default'`,
  );
  if (!settings) throw new Error('User settings are unavailable.');
  return settings;
};

export const saveUserSettings = (settings: UserSettings) => {
  validateSettings(settings);
  db.runSync(
    `UPDATE user_settings SET
       max_heart_rate = ?,
       resting_heart_rate = ?,
       running_threshold_pace = ?,
       target_weekly_distance = ?,
       cycling_ftp = ?,
       main_sport = ?
     WHERE key = 'default'`,
    [
      settings.maxHeartRate,
      settings.restingHeartRate,
      settings.runningThresholdPaceSecondsPerKm,
      settings.targetWeeklyDistanceMeters,
      settings.cyclingFTP,
      settings.mainSport,
    ],
  );
};

export const getSyncState = (provider = 'strava'): SyncState => {
  const row = db.getFirstSync<SyncStateRow>(
    `SELECT
       provider,
       connected,
       athlete_name AS athleteName,
       last_synced_at AS lastSyncedAt,
       last_error AS lastError
     FROM sync_state
     WHERE provider = ?`,
    [provider],
  );
  return row
    ? { ...row, connected: row.connected === 1 }
    : { provider, connected: false, athleteName: null, lastSyncedAt: null, lastError: null };
};

const ACTIVITY_SELECT = `SELECT
  id,
  title,
  type,
  distance,
  duration,
  date,
  tss,
  elevation_gain AS elevationGain,
  average_heart_rate AS averageHeartRate,
  average_power AS averagePower,
  average_cadence AS averageCadence,
  average_speed AS averageSpeed,
  encoded_polyline AS encodedPolyline,
  trimp,
  streams_imported AS streamsImported,
  source
FROM activities
ORDER BY date DESC`;

function ensureActivityColumns(): void {
  const existing = new Set(
    db.getAllSync<{ name: string }>('PRAGMA table_info(activities)').map(({ name }) => name),
  );
  const columns: Array<[string, string]> = [
    ['elevation_gain', 'REAL NOT NULL DEFAULT 0'],
    ['average_heart_rate', 'REAL'],
    ['average_power', 'REAL'],
    ['average_cadence', 'REAL'],
    ['average_speed', 'REAL'],
    ['encoded_polyline', 'TEXT'],
    ['trimp', 'REAL NOT NULL DEFAULT 0'],
    ['streams_imported', 'INTEGER NOT NULL DEFAULT 0'],
    ['source', "TEXT NOT NULL DEFAULT 'local'"],
  ];
  for (const [name, definition] of columns) {
    if (!existing.has(name)) {
      db.execSync(`ALTER TABLE activities ADD COLUMN ${name} ${definition};`);
    }
  }
}

function mapActivityRow(row: ActivityRow): Activity {
  return { ...row, streamsImported: row.streamsImported === 1 };
}

function finiteOrNull(value: number | undefined): number | null {
  return value !== undefined && Number.isFinite(value) ? value : null;
}

function validateActivity(activity: ActivityInput): void {
  if (!activity.id.trim() || !activity.title.trim() || !activity.type.trim()) {
    throw new Error('Activity id, title and type are required.');
  }
  if (!Number.isFinite(activity.distance) || activity.distance < 0) {
    throw new Error('Activity distance must be a non-negative number.');
  }
  if (!Number.isFinite(activity.duration) || activity.duration < 0) {
    throw new Error('Activity duration must be a non-negative number.');
  }
  if (!Number.isFinite(activity.tss) || activity.tss < 0) {
    throw new Error('Activity TSS must be a non-negative number.');
  }
  if (Number.isNaN(Date.parse(activity.date))) {
    throw new Error('Activity date must be a valid ISO date string.');
  }
}

function validateSettings(settings: UserSettings): void {
  const numericValues = [
    settings.maxHeartRate,
    settings.restingHeartRate,
    settings.runningThresholdPaceSecondsPerKm,
    settings.targetWeeklyDistanceMeters,
    settings.cyclingFTP,
  ];
  if (numericValues.some((value) => !Number.isFinite(value) || value <= 0)) {
    throw new Error('Settings must contain positive numeric values.');
  }
  if (settings.restingHeartRate >= settings.maxHeartRate) {
    throw new Error('Resting heart rate must be lower than maximum heart rate.');
  }
  if (!settings.mainSport.trim()) throw new Error('Main sport is required.');
}
