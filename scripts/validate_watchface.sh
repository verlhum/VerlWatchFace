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

# 1. Run Gradle Build (Assemble Debug)
BUILD_CMD="./gradlew :watchface:assembleDebug"

echo "Running build command: $BUILD_CMD"
eval "$BUILD_CMD" > "$LOG_DIR/build.log" 2>&1
BUILD_EXIT_CODE=$?

# Verify build artifact
APK_PATH="watchface/build/outputs/apk/debug/watchface-debug.apk"
APK_EXISTS=false
if [ -f "$APK_PATH" ]; then
    APK_EXISTS=true
fi

# 2. Robust Device Enumeration & Pixel Watch 5 Identification
WATCH_DEVICE_ID=""
PHONE_DEVICE_ID=""
WATCH_CONNECTED=false

ADB_DEVICES_LIST=$(adb devices 2>/dev/null | grep -v "List of devices" | grep -w "device" | awk '{print $1}' || true)

touch "$LOG_DIR/device_discovery.log"
for dev in $ADB_DEVICES_LIST; do
    MODEL=$(adb -s "$dev" shell getprop ro.product.model 2>/dev/null || echo "Unknown")
    CHARACTERISTICS=$(adb -s "$dev" shell getprop ro.build.characteristics 2>/dev/null || echo "Unknown")
    DEVICE_NAME=$(adb -s "$dev" shell getprop ro.product.device 2>/dev/null || echo "Unknown")

    echo "Discovered Device: $dev | Model: $MODEL | Characteristics: $CHARACTERISTICS | Device: $DEVICE_NAME" >> "$LOG_DIR/device_discovery.log"

    # Identify Pixel Watch 5
    if [[ "$MODEL" =~ [Ww]atch ]] || [[ "$CHARACTERISTICS" =~ [Ww]atch ]] || [[ "$DEVICE_NAME" =~ [Ww]atch ]] || [[ "$dev" == *"67141WRDTW61AX"* ]]; then
        WATCH_DEVICE_ID="$dev"
        WATCH_CONNECTED=true
    elif [[ "$MODEL" =~ [Pp]ixel ]] || [[ "$CHARACTERISTICS" =~ [Nn]osdcard ]]; then
        PHONE_DEVICE_ID="$dev"
    fi
done

# 3. Deployment, Activation & Screenshot Capture
INSTALL_STATUS="NOT_REQUESTED"
ACTIVATION_STATUS="NOT_REQUESTED"
SCREENSHOT_STATUS="NOT_REQUESTED"
DEPLOY_SUMMARY="Deployment not requested."

if [ "$DEPLOY" = true ]; then
    if [ "$BUILD_EXIT_CODE" -ne 0 ]; then
        INSTALL_STATUS="FAILED_BUILD_ERROR"
        ACTIVATION_STATUS="SKIPPED"
        SCREENSHOT_STATUS="SKIPPED"
        DEPLOY_SUMMARY="Deployment failed because Gradle build exited with code $BUILD_EXIT_CODE."
    elif [ "$WATCH_CONNECTED" = false ]; then
        INSTALL_STATUS="FAILED_NO_WATCH_DEVICE"
        ACTIVATION_STATUS="SKIPPED"
        SCREENSHOT_STATUS="SKIPPED"
        DEPLOY_SUMMARY="ERROR: Deployment requested via --deploy, but no Pixel Watch 5 device was found among connected ADB devices. Refusing to deploy to phone or unverified devices."
    else
        # Target ONLY the Pixel Watch 5 device for installation
        echo "Installing $APK_PATH to Pixel Watch 5 ($WATCH_DEVICE_ID)..."
        INSTALL_OUT=$(adb -s "$WATCH_DEVICE_ID" install -r "$APK_PATH" 2>&1)
        INSTALL_CODE=$?

        if [ $INSTALL_CODE -eq 0 ] && [[ "$INSTALL_OUT" =~ "Success" ]]; then
            INSTALL_STATUS="SUCCESS"
            echo "Installation on Pixel Watch 5 ($WATCH_DEVICE_ID) succeeded." > "$LOG_DIR/deployment.log"

            # Wait for Watch Face Activation
            echo "Waiting for custom watch face activation on Pixel Watch 5..."
            sleep 2

            # Verify Active Watch Face Package
            ACTIVE_DUMPSYS=$(adb -s "$WATCH_DEVICE_ID" shell dumpsys activity service com.google.wear.watchface.runtime 2>/dev/null || true)
            if [[ "$ACTIVE_DUMPSYS" =~ "com.example.verlwatchface" ]]; then
                ACTIVATION_STATUS="ACTIVE_VERIFIED"
                echo "Activation verified: com.example.verlwatchface is currently active in DWF runtime." >> "$LOG_DIR/deployment.log"
            else
                ACTIVATION_STATUS="UNVERIFIED_OR_INACTIVE"
                echo "Activation unverified: com.example.verlwatchface not detected as active wallpaper component." >> "$LOG_DIR/deployment.log"
            fi

            # Capture Screenshot from Watch
            echo "Capturing screenshot from Pixel Watch 5..."
            adb -s "$WATCH_DEVICE_ID" shell input keyevent 224 2>/dev/null || true
            sleep 1.5
            adb -s "$WATCH_DEVICE_ID" shell screencap -p /sdcard/watch_screen.png 2>/dev/null || true
            adb -s "$WATCH_DEVICE_ID" pull /sdcard/watch_screen.png "$LOG_DIR/watch_screen.png" 2>&1 || true

            if [ -f "$LOG_DIR/watch_screen.png" ] && [ $(stat -c%s "$LOG_DIR/watch_screen.png" 2>/dev/null || echo 0) -gt 2000 ]; then
                SCREENSHOT_STATUS="SUCCESS"
                cp "$LOG_DIR/watch_screen.png" "watch_screen.png" 2>/dev/null || true
                echo "Screenshot pulled successfully to $LOG_DIR/watch_screen.png." >> "$LOG_DIR/deployment.log"
            else
                SCREENSHOT_STATUS="FAILED"
                echo "ERROR: Failed to capture/pull valid screenshot from watch." >> "$LOG_DIR/deployment.log"
            fi

            DEPLOY_SUMMARY="Installation: SUCCESS | Activation: $ACTIVATION_STATUS | Screenshot: $SCREENSHOT_STATUS"
        else
            INSTALL_STATUS="FAILED_INSTALL_ERROR"
            ACTIVATION_STATUS="SKIPPED"
            SCREENSHOT_STATUS="SKIPPED"
            DEPLOY_SUMMARY="ERROR: APK installation failed on Pixel Watch 5 ($WATCH_DEVICE_ID): $INSTALL_OUT"
            echo "$DEPLOY_SUMMARY" > "$LOG_DIR/deployment.log"
        fi
    fi
else
    echo "Deployment was not requested (run with --deploy to deploy)." > "$LOG_DIR/deployment.log"
fi

# 4. Device Diagnostics Logging
if [ "$WATCH_CONNECTED" = true ]; then
    echo "Capturing logcat diagnostics from Pixel Watch 5 ($WATCH_DEVICE_ID)..."
    adb -s "$WATCH_DEVICE_ID" logcat -d | grep -i -E "com.example.verlwatchface|DWF|WatchFace|Complication" | tail -n 100 > "$LOG_DIR/device.log" 2>&1 || true
    echo "" >> "$LOG_DIR/device.log"
    echo "--- DWF Runtime Dumpsys Status ---" >> "$LOG_DIR/device.log"
    adb -s "$WATCH_DEVICE_ID" shell dumpsys activity service com.google.wear.watchface.runtime >> "$LOG_DIR/device.log" 2>&1 || true
else
    echo "No Pixel Watch 5 device connected. Device logs not captured." > "$LOG_DIR/device.log"
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

## Deployment Status Dashboard
- **Target Watch Device ID:** \`${WATCH_DEVICE_ID:-NONE}\`
- **Installation Status:** \`$INSTALL_STATUS\`
- **Activation Status:** \`$ACTIVATION_STATUS\`
- **Screenshot Status:** \`$SCREENSHOT_STATUS\`

## Modifiers & Assets
- **Main WFF File:** \`watchface/src/main/res/raw/watchface.xml\`
- **Validation Script:** \`scripts/validate_watchface.sh\`
EOF

# 6. Generate validation.md
cat <<EOF > "$LOG_DIR/validation.md"
# Validation Report - $TIMESTAMP

## 1. WFF Configuration
- **WFF Version:** 2 (\`com.google.wear.watchface.format.version = 2\`)
- **Min SDK:** 36 | **Target SDK:** 37
- **Canvas Resolution:** 450 x 450 (Center at 225, 225)
- **Executable Code:** None (\`hasCode="false"\`)

## 2. Deployment Verification
- **Pixel Watch 5 Connected:** \`$WATCH_CONNECTED\` (\`${WATCH_DEVICE_ID:-NONE}\`)
- **APK Installation:** \`$INSTALL_STATUS\`
- **Watch Face Activation:** \`$ACTIVATION_STATUS\`
- **ADB Screenshot Capture:** \`$SCREENSHOT_STATUS\`

## 3. Artifact Verification
- **APK Path:** \`$APK_PATH\`
- **APK Exists:** \`$APK_EXISTS\`
- **Build Exit Code:** \`$BUILD_EXIT_CODE\`
EOF

# 7. Generate summary.md
cat <<EOF > "$LOG_DIR/summary.md"
# Execution Summary - $TIMESTAMP

## Overview
- **Objective:** Automated build, Pixel Watch 5 validation, and verified deployment logging.
- **Timestamp:** $TIMESTAMP
- **Log Directory:** \`$LOG_DIR\`

## Status Dashboard
- **Gradle Build:** $( [ $BUILD_EXIT_CODE -eq 0 ] && echo "SUCCESS (Exit Code 0)" || echo "FAILED (Exit Code $BUILD_EXIT_CODE)" )
- **APK Artifact:** $( [ "$APK_EXISTS" = true ] && echo "VERIFIED ($APK_PATH)" || echo "MISSING" )
- **Pixel Watch 5 Connected:** $( [ "$WATCH_CONNECTED" = true ] && echo "YES ($WATCH_DEVICE_ID)" || echo "NO" )
- **Installation:** \`$INSTALL_STATUS\`
- **Activation:** \`$ACTIVATION_STATUS\`
- **Screenshot Capture:** \`$SCREENSHOT_STATUS\`

## Log File References
- Change History & Git Context: [\`changes.md\`](file://$PROJECT_ROOT/$LOG_DIR/changes.md)
- Full Build Output: [\`build.log\`](file://$PROJECT_ROOT/$LOG_DIR/build.log)
- WFF Technical Validation: [\`validation.md\`](file://$PROJECT_ROOT/$LOG_DIR/validation.md)
- Deployment Log: [\`deployment.log\`](file://$PROJECT_ROOT/$LOG_DIR/deployment.log)
- Device Logcat & DWF Status: [\`device.log\`](file://$PROJECT_ROOT/$LOG_DIR/device.log)
EOF

echo "===================================================="
echo "Workflow completed."
echo "Build Exit Code: $BUILD_EXIT_CODE"
echo "Deployment Summary: $DEPLOY_SUMMARY"
echo "Logs written to: $LOG_DIR"
echo "===================================================="

# Return original build exit code
exit $BUILD_EXIT_CODE