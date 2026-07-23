# TezDav Android — Liquid Glass redesign

Редизайн переносит визуальные принципы исходного iOS-ТЗ на Android/React Native, не меняя SQLite, расчёты CTL/ATL/TSB, Records, Health Connect и структуру из пяти вкладок.

## Что реализовано

- единые токены цвета, типографики, радиусов, размеров и отступов в `src/DesignSystem`;
- глубокий графитовый ambient-фон с мягкими emerald/ruby-источниками света;
- непрозрачные матовые поверхности для данных и отдельный полупрозрачный слой для кнопок, сегментов и навигации;
- плавающий таб-бар с emerald-тинтом активной вкладки и компактным состоянием при прокрутке;
- Large Title с переходом в inline-заголовок при прокрутке;
- общий Empty State, Glass Button, сегмент-контрол с пружинным индикатором, Metric Tile и Record Row;
- интерактивный PMC-график CTL/ATL/TSB: линии, area-fill, переключаемая легенда и tooltip по нажатию/drag;
- карта-подложка и нижний лист маршрутов без зависимости от внешнего Google Maps API key;
- пользовательская микрокопия Strava вместо технического сообщения о токенах;
- haptic-отклик для кнопок и переключателей через `expo-haptics`.

## Android-адаптация материала

`expo-glass-effect` использует iOS `UIVisualEffectView` и на Android откатывается к обычному `View`, поэтому он не применяется. Повторяющиеся Android `BlurView` с RenderNode во время device-QA вызвали пропуски дочерних элементов таб-бара и ANR. Итоговый Android-материал построен на нескольких лёгких слоях: полупрозрачная графитовая база, адаптивный tint, тонкая обводка и диагональный specular-gradient. Так сохраняются глубина и световой отклик без нестабильной GPU-композиции.

Контентные карточки намеренно непрозрачны. «Стекло» используется только для управляющего слоя: tab bar, segmented controls, CTA, legend chips и иконки empty state.

## Доступность

`AccessibilityProvider` слушает `reduceMotionChanged` и `reduceTransparencyChanged`.

- Reduce Motion заменяет пружинные переходы на короткий timing-переход.
- Reduce Transparency делает управляющие поверхности полностью непрозрачными.
- Основной и вторичный текст используют контрастные токены; значения метрик используют tabular figures.
- Интерактивные элементы имеют accessibility role/state и минимальную высоту 48 dp.

На Android нет единого пользовательского переключателя Reduce Transparency, эквивалентного iOS. Фолбэк всё равно реализован через React Native Accessibility API для устройств/оболочек, которые публикуют это состояние.

## Скриншоты

- [Главная](screenshots/redesign/dashboard.png)
- [Форма](screenshots/redesign/form.png)
- [Рекорды](screenshots/redesign/records.png)
- [Карта](screenshots/redesign/routes.png)
- [Профиль](screenshots/redesign/profile.png)

Скриншоты сняты на Android API 36 в тёмной теме с пустой локальной базой, то есть без demo seed и фиктивных метрик.

## Проверка

```bash
npm run verify
npx expo export --platform android
```

Нативная проверка после `npx expo prebuild --platform android`:

```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
ANDROID_HOME="$HOME/Library/Android/sdk" \
./gradlew :app:lintDebug :app:assembleDebug :app:assembleRelease :app:lintVitalRelease \
  -PreactNativeArchitectures=arm64-v8a
```

Release APK остаётся unsigned по существующему правилу проекта; production-подпись должна приходить из EAS credentials или отдельного keystore.
