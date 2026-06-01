#!/bin/bash
# TezDav Screenshot Capture Script
# Usage: ./scripts/take_screenshots.sh
# Requires the app to be running on a booted simulator with demo data loaded.

SIMULATOR_ID="695152E0-94A1-4E9F-9913-762FB3B2B28E"
OUT_DIR="docs/screenshots"
mkdir -p "$OUT_DIR"

echo "📸 Starting TezDav screenshot session..."
echo "   Simulator: $SIMULATOR_ID"
echo "   Output: $OUT_DIR"
echo ""

take_screenshot() {
    local name="$1"
    local delay="${2:-2}"
    sleep "$delay"
    xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/$name.png"
    echo "✅ Captured: $OUT_DIR/$name.png"
}

# Open the app
echo "🚀 Launching TezDav..."
xcrun simctl launch "$SIMULATOR_ID" com.hafizov.tezdav 2>/dev/null || true
sleep 3

# Tab 0: Dashboard
echo "📊 Dashboard..."
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/dashboard.png"
echo "✅ dashboard.png"
sleep 1

# Tap tab 1 (Form/Fitness)
echo "📈 Form/Fitness tab..."
# x=77 y=860 is tab 1 on iPhone 17
xcrun simctl io "$SIMULATOR_ID" sendkey 1  2>/dev/null || true
sleep 2
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/form_fitness.png"
echo "✅ form_fitness.png"

# Tap tab 2 (Routes/Map)
echo "🗺  Routes/Map tab..."
sleep 2
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/map_routes.png"
echo "✅ map_routes.png"

# Tap tab 3 (Social)
echo "👥 Social tab..."
sleep 2
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/social_feed.png"
echo "✅ social_feed.png"

# Tap tab 4 (Records)
echo "🏆 Records tab..."
sleep 2
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/records.png"
echo "✅ records.png"

# Tap tab 5 (Profile)
echo "👤 Profile tab..."
sleep 2
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUT_DIR/profile_settings.png"
echo "✅ profile_settings.png"

echo ""
echo "🎉 All screenshots captured in $OUT_DIR/"
ls -la "$OUT_DIR/"*.png
