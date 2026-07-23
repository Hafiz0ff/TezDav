# TezDav Android — Handoff

Актуально на 16 июля 2026 года.

## Liquid Glass redesign

Пять основных экранов переведены на Android-адаптацию Liquid Glass. Дизайн-токены и переиспользуемые компоненты находятся в `src/DesignSystem` и `src/Components`; описание решений и device-QA скриншоты — в `docs/LIQUID_GLASS_ANDROID.md`.

На Android не используется `expo-glass-effect` (он нативный только для iOS) и не оставлен повторяющийся RenderNode blur: во время проверки он вызывал пропуски элементов таб-бара и ANR. Управляющие поверхности используют стабильную многослойную translucency/specular-gradient реализацию; карточки данных остаются непрозрачными.

## Текущее состояние

Проект находится в `/Users/hafizov/Dav.TJ/Android`. В корневом Git-репозитории каталог `Android` пока полностью untracked; коммит в рамках аудита не создавался. Существующие изменения Swift-проекта не затрагивались.

Android запускается сразу на Dashboard без формы логина. Реализованы вкладки:

- Главная: CTL/ATL/TSB, недельный объём, последние тренировки, Health Connect steps.
- Форма: PMC с периодами 30/90 дней/вся история.
- Рекорды: лучшие беговые отрезки, Daniels VO2max, Riegel, отчёт за 30 дней.
- Карта: активности с GPS-полилиниями и офлайн-контур маршрута в деталях.
- Профиль: локальные пороги, FTP, пульс и недельная цель.

Экраны заполняются только реальными локальными данными. Demo seed и mock-метрики отсутствуют.

## Важная граница готовности

Strava-клиент для Android не реализован. В iOS он есть, но Android-проект изначально был независимым прототипом и не содержал соответствующего кода. Сейчас отсутствуют:

- OAuth authorization/code exchange и secure token storage;
- refresh access token;
- историческая пагинация активностей;
- импорт activity details/streams/polyline;
- rate-limit queue;
- фоновая синхронизация.

Не добавлять `STRAVA_CLIENT_SECRET` в `app.json`, `.env` с `EXPO_PUBLIC_` или APK. Strava требует secret при token exchange и одновременно запрещает его раскрытие. Рекомендуемое продолжение — небольшой token broker, который обменивает code/refresh token, а мобильный клиент хранит refresh token через Android Keystore (`expo-secure-store`). Официальное описание: https://developers.strava.com/docs/authentication/

## Быстрый старт

```bash
cd /Users/hafizov/Dav.TJ/Android
npm ci
npm run verify
```

Debug-разработка требует Metro:

```bash
npm start
npm run android
```

`Unable to load script` означает, что установлен debug APK, но Metro не запущен. Автономный release содержит JS bundle.

Локальная нативная проверка:

```bash
cd /Users/hafizov/Dav.TJ/Android
npx expo prebuild --platform android
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
ANDROID_HOME="$HOME/Library/Android/sdk" \
./gradlew :app:lintDebug :app:assembleDebug :app:assembleRelease :app:lintVitalRelease \
  -PreactNativeArchitectures=arm64-v8a
```

Release APK намеренно создаётся как `app-release-unsigned.apk`. Для распространения подключить production keystore или EAS credentials; не возвращать debug signing в release.

## Архитектура

- `App.tsx` — root stack и пять bottom tabs.
- `src/Database/database.ts` — SQLite schema v2, миграция, repositories.
- `src/TrainingMetrics/TrainingLoadCalculator.ts` — CTL/ATL/TSB.
- `src/TrainingMetrics/ActivityMetricsEngine.ts` — splits, HR zones, normalized power.
- `src/TrainingMetrics/AnalyticsEngine.ts` — records, Daniels, Riegel.
- `src/Screens` — основные экраны.
- `src/Components/RouteTrace.tsx` — офлайн-визуализация encoded polyline.
- `src/Health/healthConnect.ts` — explicit-consent чтение шагов.
- `plugins/withAndroidHardening.js` — нативные permissions, backup rules, Health Connect delegate, release signing guard.
- `docs/AUDIT_REPORT_2026-07-16.md` — полный отчёт аудита.

Нативные `/android` и `/ios` генерируются Expo prebuild и игнорируются Git. Все необходимые нативные изменения должны вноситься через `app.json` или config plugin, иначе следующий prebuild их удалит.

## SQLite schema v2

- `activities` — сводная активность и сохранённые метрики;
- `activity_stream_samples` — секунды, дистанция, HR, cadence, power, speed, elevation, GPS;
- `user_settings` — пороги и цели;
- `sync_state` — состояние провайдера.

При импорте сначала upsert activity, затем `replaceActivityStreamSamples`. После расчётов сохранить TSS/TRIMP и `streamsImported=true`. Все даты хранить в ISO 8601 UTC.

## Следующий этап

1. Зафиксировать архитектуру Strava token broker и redirect URI `tezdav://auth/callback`.
2. Добавить `expo-auth-session`, `expo-web-browser`, `expo-secure-store` и state validation.
3. Реализовать token refresh и только после него пагинированный импорт summary activities.
4. Добавить очередь detail/stream запросов с учётом `X-RateLimit-Limit` и `X-RateLimit-Usage`.
5. Сохранять activity и streams транзакционно; повторный импорт должен быть идемпотентным.
6. Подключить Android background task с ограничениями ОС; не обещать точный запуск раз в час.
7. Добавить Google Maps API key через защищённую build-конфигурацию и полноценную map view.
8. Прогнать импорт полной истории реального аккаунта и профилировать Records/Activity Detail.

## Проверки перед продолжением

Текущая база качества:

- TypeScript strict: pass;
- Vitest: 13/13;
- Expo Doctor: 20/20;
- Android lint/lintVital: 0 errors;
- debug/release ARM64 build: pass;
- повторный release cold start API 36: 423 ms;
- runtime smoke: пять вкладок, без FATAL/SQLite/React Native errors;
- release permissions: INTERNET, VIBRATE, READ_STEPS, internal receiver permission;
- release bundle: без Supabase/Strava Client Secret markers.

После Strava-интеграции обязательны тесты OAuth cancel/state mismatch, refresh rotation, scope mismatch, pagination restart, HTTP 429 pause, partial stream failure, offline launch и повторная синхронизация без дублей.
