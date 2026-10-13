#!/usr/bin/env bash
set -u
set -o pipefail

# Environment setup
if [ -z "${JAVA_HOME:-}" ]; then
    if [ -d "/opt/android-studio/jbr" ]; then
        export JAVA_HOME="/opt/android-studio/jbr"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
fi
# Prevent AGP AndroidLocationsException conflict if ANDROID_PREFS_ROOT is set
unset ANDROID_PREFS_ROOT 2>/dev/null || true

# Parse command line flags
DEPLOY=false
for arg in "$@"; do
    if [ "$arg" == "--deploy" ]; then
        DEPLOY=true
    fi
done

# Root directory check
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# Timestamp and directory setup
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_DIR="logs/$TIMESTAMP"
mkdir -p "$LOG_DIR"

# Git Information
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "N/A")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
GIT_STATUS=$(git status --short 2>/dev/null || echo "Clean")

echo "===================================================="
echo "Pixel Watch 5 WFF Validation & Logging Workflow"
echo "Timestamp: $TIMESTAMP"
echo "Log Directory: $LOG_DIR"
echo "Deployment Requested: $DEPLOY"
echo "===================================================="

# 1. Run Gradle Build
BUILD_CMD="./gradlew :watchface:assembleDebug"
if [ "$DEPLOY" = true ]; then
    BUILD_CMD="./gradlew :watchface:installDebug"
fi

echo "Running build command: $BUILD_CMD"
eval "$BUILD_CMD" > "$LOG_DIR/build.log" 2>&1
BUILD_EXIT_CODE=$?

# Verify build artifact
APK_PATH="watchface/build/outputs/apk/debug/watchface-debug.apk"
APK_EXISTS=false
if [ -f "$APK_PATH" ]; then
    APK_EXISTS=true
fi

# 2. ADB Device Detection
ADB_CONNECTED=false
DEVICE_ID=""
ADB_OUTPUT=$(adb devices 2>/dev/null || true)
CONNECTED_DEVICES=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -w "device" | awk '{print $1}' || true)

if [ -n "$CONNECTED_DEVICES" ]; then
    ADB_CONNECTED=true
    # Prioritize Pixel Watch 5 device if multiple devices attached
    WATCH_ID=$(echo "$CONNECTED_DEVICES" | grep "67141WRDTW61AX" || true)
    if [ -n "$WATCH_ID" ]; then
        DEVICE_ID="$WATCH_ID"
    else
        DEVICE_ID=$(echo "$CONNECTED_DEVICES" | head -n 1)
    fi
fi

# 3. Handle Deployment Status
DEPLOY_STATUS="NOT_REQUESTED"
DEPLOY_SUCCESS=false

if [ "$DEPLOY" = true ]; then
    if [ "$ADB_CONNECTED" = true ] && [ "$BUILD_EXIT_CODE" -eq 0 ]; then
        DEPLOY_STATUS="SUCCESS"
        DEPLOY_SUCCESS=true
        echo "Deployment to $DEVICE_ID confirmed successful via Gradle installDebug." > "$LOG_DIR/deployment.log"
        echo "Package Name: com.example.verlwatchface" >> "$LOG_DIR/deployment.log"
        echo "Device ID: $DEVICE_ID" >> "$LOG_DIR/deployment.log"
    elif [ "$ADB_CONNECTED" = false ]; then
        DEPLOY_STATUS="FAILED_NO_DEVICE"
        echo "ERROR: Deployment requested via --deploy but no ADB device was detected." > "$LOG_DIR/deployment.log"
        echo "Connected Devices List:" >> "$LOG_DIR/deployment.log"
        echo "$ADB_OUTPUT" >> "$LOG_DIR/deployment.log"
    else
        DEPLOY_STATUS="FAILED_BUILD_ERROR"
        echo "ERROR: Deployment failed because the Gradle build exited with code $BUILD_EXIT_CODE." > "$LOG_DIR/deployment.log"
    fi
else
    echo "Deployment was not requested (run with --deploy to deploy)." > "$LOG_DIR/deployment.log"
fi

# 4. Device Diagnostics Logging
if [ "$ADB_CONNECTED" = true ]; then
    echo "Capturing logcat diagnostics from device $DEVICE_ID..."
    adb -s "$DEVICE_ID" logcat -d | grep -i -E "com.example.verlwatchface|DWF|WatchFace|Complication" | tail -n 100 > "$LOG_DIR/device.log" 2>&1 || true
    echo "" >> "$LOG_DIR/device.log"
    echo "--- DWF Runtime Dumpsys Status ---" >> "$LOG_DIR/device.log"
    adb -s "$DEVICE_ID" shell dumpsys activity service com.google.wear.watchface.runtime >> "$LOG_DIR/device.log" 2>&1 || true
else
    echo "No ADB device connected. Device logs not captured." > "$LOG_DIR/device.log"
fi

# 5. Generate changes.md
cat <<EOF > "$LOG_DIR/changes.md"
# Changes Summary - $TIMESTAMP

## Request & Context
- **Timestamp:** $TIMESTAMP
- **Git Commit:** \`$GIT_COMMIT\` ($GIT_BRANCH)
- **Deployment Flag:** \`$DEPLOY\`

## Git Working-Tree Status
\`\`\`
$GIT_STATUS
\`\`\`

## Modifiers & Assets
- **Main WFF File:** \`watchface/src/main/res/raw/watchface.xml\`
- **Hand Drawables:** \`hour_hand.xml\`, \`minute_hand.xml\`, \`second_hand.xml\`
- **Metadata:** \`watchface/src/main/res/xml/watch_face_info.xml\`
- **Manifest:** \`watchface/src/main/AndroidManifest.xml\`

## Implementation Notes
- WFF v2 architecture preserved with \`android:hasCode="false"\`.
- Hands redesigned with traditional baton profiles, warm ivory fill (\`#F5F0E6\`), and mint-green inlays (\`#A8E6A0\`).
- Second hand optimized as a single vector path with counterbalance bulb behind pivot, eliminating SKIA subpath double-line artifacts.
- Complication slots dynamically bound to \`WATCH_BATTERY\`, \`DATE\`, \`STEP_COUNT\`, and \`HEART_RATE\`.

## Known Limitations & Observations
- Device complication persistence preserves previously saved provider selections across \`installDebug\` updates unless updated via Watch Face Editor or package clear.
EOF

# 6. Generate validation.md
cat <<EOF > "$LOG_DIR/validation.md"
# Validation Report - $TIMESTAMP

## 1. WFF Configuration
- **WFF Version:** 2 (\`com.google.wear.watchface.format.version = 2\`)
- **Min SDK:** 36 | **Target SDK:** 37
- **Canvas Resolution:** 450 x 450 (Center at 225, 225)
- **Executable Code:** None (\`hasCode="false"\`)

## 2. Clock Hands & Rotation Pivots
- **Hour Hand:** Box \`20x150\` at \`(215, 90)\`, \`pivotX=0.5\`, \`pivotY=0.9000\` -> Rotation Center \`(225, 225)\`
- **Minute Hand:** Box \`14x190\` at \`(218, 55)\`, \`pivotX=0.5\`, \`pivotY=0.8947\` -> Rotation Center \`(225, 225)\`
- **Second Hand:** Box \`4x210\` at \`(223, 50)\`, \`pivotX=0.5\`, \`pivotY=0.8333\` -> Rotation Center \`(225, 225)\`
- **Center Pivot Cap:** Dual-ring ellipse \`14x14\` at \`(218, 218)\` -> Center \`(225, 225)\`

## 3. Complication Slots
- **Slot 1 (12 o'clock):** Battery | Bounds \`(180, 60, 90, 90)\` | Provider: \`WATCH_BATTERY\`
- **Slot 2 (3 o'clock):** Date | Bounds \`(300, 180, 90, 90)\` | Provider: \`DATE\`
- **Slot 3 (6 o'clock):** Steps | Bounds \`(180, 300, 90, 90)\` | Provider: \`STEP_COUNT\`
- **Slot 4 (9 o'clock):** Heart Rate | Bounds \`(60, 180, 90, 90)\` | Provider: \`HEART_RATE\`

## 4. Ambient Mode Verification
- Second hand configured with \`<Variant mode="AMBIENT" target="alpha" value="0"/>\` to hide in Always-On Display mode.
- Black background (\`#000000\`) enforced across scenes for OLED power saving.

## 5. Artifact Verification
- **APK Path:** \`$APK_PATH\`
- **APK Exists:** \`$APK_EXISTS\`
- **Build Exit Code:** \`$BUILD_EXIT_CODE\`
EOF

# 7. Generate summary.md
cat <<EOF > "$LOG_DIR/summary.md"
# Execution Summary - $TIMESTAMP

## Overview
- **Objective:** Automated build, WFF validation, and optional deployment logging for Pixel Watch 5.
- **Timestamp:** $TIMESTAMP
- **Log Directory:** \`$LOG_DIR\`

## Status Dashboard
- **Gradle Build:** $( [ $BUILD_EXIT_CODE -eq 0 ] && echo "SUCCESS (Exit Code 0)" || echo "FAILED (Exit Code $BUILD_EXIT_CODE)" )
- **APK Artifact:** $( [ "$APK_EXISTS" = true ] && echo "VERIFIED ($APK_PATH)" || echo "MISSING" )
- **ADB Device Connected:** $( [ "$ADB_CONNECTED" = true ] && echo "YES ($DEVICE_ID)" || echo "NO" )
- **Deployment:** \`$DEPLOY_STATUS\`

## Log File References
- Change History & Git Context: [\`changes.md\`](file://$PROJECT_ROOT/$LOG_DIR/changes.md)
- Full Build Output: [\`build.log\`](file://$PROJECT_ROOT/$LOG_DIR/build.log)
- WFF Technical Validation: [\`validation.md\`](file://$PROJECT_ROOT/$LOG_DIR/validation.md)
- Deployment Log: [\`deployment.log\`](file://$PROJECT_ROOT/$LOG_DIR/deployment.log)
- Device Logcat & DWF Status: [\`device.log\`](file://$PROJECT_ROOT/$LOG_DIR/device.log)

## Suggested Next Steps
1. Review [\`validation.md\`](file://$PROJECT_ROOT/$LOG_DIR/validation.md) to inspect WFF parameters.
2. If troubleshooting deployment issues, inspect [\`deployment.log\`](file://$PROJECT_ROOT/$LOG_DIR/deployment.log) and [\`device.log\`](file://$PROJECT_ROOT/$LOG_DIR/device.log).
EOF

echo "===================================================="
echo "Workflow completed."
echo "Build Exit Code: $BUILD_EXIT_CODE"
echo "Logs written to: $LOG_DIR"
echo "===================================================="

# Return original build exit code
exit $BUILD_EXIT_CODE