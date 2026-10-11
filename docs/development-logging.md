# Watch Face Development Logging & Validation Workflow

This document describes the automated logging, validation, and deployment workflow for the **Pixel Watch 5 (45 mm)** custom Watch Face Format (WFF) project.

---

## 1. Quick Start

### Build and Validate Only (Local Check)
To compile the project and generate a complete technical validation report without deploying to a watch:

```bash
./scripts/validate_watchface.sh
```

### Build, Validate, and Deploy (On-Device Test)
To compile, validate, and deploy the watch face to a connected Pixel Watch 5 over ADB:

```bash
./scripts/validate_watchface.sh --deploy
```

---

## 2. Directory & Log Structure

Each execution creates a timestamped subdirectory inside `logs/` (`logs/YYYYMMDD-HHMMSS/`). The `logs/` directory is excluded from version control in `.gitignore`.

```
logs/
└── 20261011-191500/
    ├── changes.md       # Summary of changes, Git commit hash, and working-tree status
    ├── build.log         # Full Gradle build output (stdout and stderr)
    ├── validation.md    # Technical WFF validation (pivots, bounds, providers, AOD)
    ├── deployment.log   # ADB device detection, package name, and deployment status
    ├── device.log       # Device logcat diagnostic messages and DWF runtime dumpsys
    └── summary.md      # Dashboard summary with exit codes and links to log files
```

---

## 3. Log File Descriptions

1. **`changes.md`**
   - Timestamp, Git commit hash, active branch, and `git status` output.
   - List of modified files (`watchface.xml`, drawables, manifest).
   - Relevant design and technical implementation decisions.

2. **`build.log`**
   - Exact Gradle build command line executed (`./gradlew :watchface:assembleDebug` or `:watchface:installDebug`).
   - Unmodified stdout/stderr output from AAPT2, Gradle, and compiler tools.
   - Preserves exit code (`0` for success, non-zero for failure).

3. **`validation.md`**
   - WFF version declaration (`com.google.wear.watchface.format.version = 2`).
   - Clock hand dimensions, bounding boxes, and rotation pivots mathematically verified against center `(225, 225)`.
   - Complication slot positions, default system providers (`WATCH_BATTERY`, `DATE`, `STEP_COUNT`, `HEART_RATE`), and bounds.
   - Ambient Mode (AOD) status.
   - APK output artifact verification.

4. **`deployment.log`**
   - ADB device detection status (`adb devices`).
   - Confirmation of deployment target (e.g. `adb-67141WRDTW61AX-nkyn6T`).
   - Record of deployment result (`SUCCESS`, `FAILED_NO_DEVICE`, or `FAILED_BUILD_ERROR`).

5. **`device.log`**
   - Logcat entries filtered for `com.example.verlwatchface`, `DWF` (Declarative Watch Face runtime), and `WatchFace`.
   - Output from `dumpsys activity service com.google.wear.watchface.runtime` showing active complication slot data sources and fallback policies.

6. **`summary.md`**
   - High-level execution dashboard with status indicators for build, artifact, device, and deployment.
   - Direct file URLs to all log files for easy navigation in Android Studio.

---

## 4. How to Interpret Failures & Share Logs

### Interpreting Failures
- **Build Failure (Exit Code ≠ 0):** Check `build.log` for AAPT2 XML schema validation errors or Gradle build issues.
- **Deployment Failure (`FAILED_NO_DEVICE`):** Check `deployment.log` to see if ADB detected your watch. Verify Wireless/USB ADB debugging is enabled on the Pixel Watch 5.
- **Rendering / Complication Failure:** Check `device.log` to see if Wear OS `DeclarativeWatchFaceRuntime` reported missing data or fallback data source warnings.

### Troubleshooting Package
When requesting independent review or troubleshooting assistance without direct Android Studio access, share the entire timestamped directory:

`logs/YYYYMMDD-HHMMSS/`
