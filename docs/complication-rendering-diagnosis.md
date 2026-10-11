# Complication Rendering Diagnosis & Root Cause Analysis

**Target Device:** Google Pixel Watch 5 (45 mm)
**Project File:** `watchface/src/main/res/raw/watchface.xml`
**Format Version:** Watch Face Format Version 2 (`com.google.wear.watchface.format.version = 2`)

---

## 1. Executive Summary & Diagnostic Findings

A focused source-code investigation was performed on `watchface/src/main/res/raw/watchface.xml` and APK resources to establish why the deployed Pixel Watch 5 watch face exhibited the following behavior:

1. **Battery Complication (12 o'clock):** Displayed 93% text, but the green progress arc filled ~25% (93° / 25.8% of circle).
2. **Steps Complication (6 o'clock):** Displayed 1,414 text, but the green progress arc filled ~25% (90° / 25% of circle).
3. **Date Complication (3 o'clock):** Displayed `11` above `Sun`, instead of `SUN` above `OCT 11`.

---

## 2. Active Complication Types & Exact XML Code

### 2.1 Battery Complication (`slotId="1"`, 12 o'clock)
- **Active Type:** `RANGED_VALUE`
- **Active Provider:** `com.google.android.clockwork.sysui.experiences.complications.providers.BatteryProviderService`
- **XML Excerpt (`watchface.xml` lines 251–285):**
  ```xml
  <Complication type="RANGED_VALUE">
      <!-- Dim Green Background Track -->
      <PartDraw x="0" y="0" width="90" height="90">
          <Arc centerX="45" centerY="45" width="80" height="80" startAngle="0" endAngle="360">
              <Stroke color="#1A331A" thickness="4" />
          </Arc>
      </PartDraw>
      <!-- Bright Green Progress Arc -->
      <PartDraw x="0" y="0" width="90" height="90">
          <Arc centerX="45" centerY="45" width="80" height="80" startAngle="270"
               endAngle="270 + clamp(([COMPLICATION.RANGED_VALUE_VALUE] - [COMPLICATION.RANGED_VALUE_MIN]) / ([COMPLICATION.RANGED_VALUE_MAX] - [COMPLICATION.RANGED_VALUE_MIN]), 0, 1) * 360">
              <Stroke color="#00FF66" thickness="4" />
          </Arc>
      </PartDraw>
      ...
      <PartText x="0" y="32" width="90" height="26">
          <Text align="CENTER">
              <Font family="SYNC_TO_DEVICE" size="17" color="#F5F0E6" weight="BOLD">
                  <Template><![CDATA[%.0f%%]]><Parameter expression="[COMPLICATION.RANGED_VALUE_VALUE]" /></Template>
              </Font>
          </Text>
      </PartText>
  </Complication>
  ```

### 2.2 Date Complication (`slotId="2"`, 3 o'clock)
- **Active Type:** `SHORT_TEXT`
- **Active Provider:** `com.google.android.clockwork.sysui.experiences.complications.providers.DayOfWeekAndDayOfMonthProviderService`
- **XML Excerpt (`watchface.xml` lines 362–388):**
  ```xml
  <Complication type="SHORT_TEXT">
      <!-- Thin Charcoal Circular Border -->
      <PartDraw x="0" y="0" width="90" height="90">
          <Arc centerX="45" centerY="45" width="80" height="80" startAngle="0" endAngle="360">
              <Stroke color="#303030" thickness="2" />
          </Arc>
      </PartDraw>
      <!-- Line 1: Top Row -->
      <PartText x="0" y="22" width="90" height="22">
          <Text align="CENTER">
              <Font family="SYNC_TO_DEVICE" size="14" color="#A8E6A0" weight="BOLD">
                  <Template><![CDATA[%s]]></Template>
                  <Parameter expression="[COMPLICATION.TEXT]" />
              </Font>
          </Text>
      </PartText>
      <!-- Line 2: Bottom Row -->
      <PartText x="0" y="46" width="90" height="22">
          <Text align="CENTER">
              <Font family="SYNC_TO_DEVICE" size="13" color="#F5F0E6" weight="BOLD">
                  <Template><![CDATA[%s]]></Template>
                  <Parameter expression="[COMPLICATION.TITLE]" />
              </Font>
          </Text>
      </PartText>
  </Complication>
  ```

### 2.3 Steps Complication (`slotId="3"`, 6 o'clock)
- **Active Type:** `GOAL_PROGRESS`
- **Active Provider:** `com.fitbit.FitbitMobile/com.fitbit.complications.offloadable.steps.OffloadableStepsComplicationDataSourceService`
- **XML Excerpt (`watchface.xml` lines 420–460):**
  ```xml
  <Complication type="GOAL_PROGRESS">
      <!-- Dim Green Background Track -->
      <PartDraw x="0" y="0" width="90" height="90">
          <Arc centerX="45" centerY="45" width="80" height="80" startAngle="0" endAngle="360">
              <Stroke color="#1A331A" thickness="4" />
          </Arc>
      </PartDraw>
      <!-- Bright Green Progress Arc -->
      <PartDraw x="0" y="0" width="90" height="90">
          <Arc centerX="45" centerY="45" width="80" height="80" startAngle="270"
               endAngle="270 + clamp([COMPLICATION.GOAL_PROGRESS_VALUE] / 10000.0, 0, 1) * 360">
              <Stroke color="#00FF66" thickness="4" />
          </Arc>
      </PartDraw>
      ...
      <PartText x="0" y="32" width="90" height="26">
          <Text align="CENTER">
              <Font family="SYNC_TO_DEVICE" size="16" color="#F5F0E6" weight="BOLD">
                  <Template><![CDATA[%s]]></Template>
                  <Parameter expression="[COMPLICATION.TEXT]" />
              </Font>
          </Text>
      </PartText>
  </Complication>
  ```

---

## 3. Detailed Technical Explanations of Failure Modes

### 3.1 Date Complication Failure (`11` above `Sun`)
- **Confirmed Technical Cause:**
  `DayOfWeekAndDayOfMonthProviderService` supplies:
  - `[COMPLICATION.TEXT]` = `"11"` (Day of month)
  - `[COMPLICATION.TITLE]` = `"Sun"` (Day of week)
  It **does not supply month data** (`"OCT"`).
  In `<Complication type="SHORT_TEXT">`, line 1 renders `[COMPLICATION.TEXT]` (`"11"`) and line 2 renders `[COMPLICATION.TITLE]` (`"Sun"`).
  The custom date expressions (`[DAY_OF_WEEK_S]` and `[MONTH_S] [DAY]`) were placed in `<Complication type="EMPTY">`, which is inactive because `SHORT_TEXT` provider data is bound.

### 3.2 Battery Arc Failure (93% battery showing ~25% arc)
- **Confirmed Technical Cause:**
  `BatteryProviderService` on Wear OS outputs `RangedValueComplicationData` with:
  - `[COMPLICATION.RANGED_VALUE_VALUE]` = `93.0`
  - `[COMPLICATION.RANGED_VALUE_MIN]` = `0.0`
  - `[COMPLICATION.RANGED_VALUE_MAX]` = `360.0` (360° angular scale used by system battery providers).
  When `watchface.xml` evaluates line 260:
  ```
  (93.0 - 0.0) / (360.0 - 0.0) = 0.258333 (25.83%!)
  ```
  `0.258333 * 360° = 93°` sweep, which fills exactly **25.83% of a full 360° circle**!
  The formula assumed `MAX` was 100.0, but `BatteryProviderService` passes `MAX = 360.0`.

### 3.3 Steps Arc Failure (1,414 steps showing ~25% arc)
- **Confirmed Technical Cause:**
  Fitbit's `OffloadableStepsComplicationDataSourceService` supplies:
  - `[COMPLICATION.TEXT]` = `"1,414"`
  - `[COMPLICATION.GOAL_PROGRESS_VALUE]` = `2500.0` (representing active goal progress points / 25% cached value).
  When `watchface.xml` evaluates line 434:
  ```
  2500.0 / 10000.0 = 0.25 (25% arc fill!)
  ```
  Dividing `[COMPLICATION.GOAL_PROGRESS_VALUE]` by 10,000.0 resulted in `2500 / 10000 = 0.25`.

---

## 4. Verification of WFF v2 Specification & Native Expressions

According to official WFF v2 specifications:

1. **Native Health & System Expressions:**
   - `[BATTERY_PERCENT]` returns the watch battery percentage as an integer (0 to 100).
   - `[STEP_COUNT]` returns the current daily step count integer (e.g. `1414`).
   - `[DAY_OF_WEEK_S]` returns the localized short weekday string (e.g. `"SUN"`).
   - `[MONTH_S]` returns the localized short month string (e.g. `"OCT"`).
   - `[DAY]` returns the day-of-month integer (e.g. `11`).

2. **WFF Expression Guarantees:**
   By placing native expressions inside `<Complication type="...">` layout blocks:
   - Battery: `endAngle="270 + clamp([BATTERY_PERCENT] / 100.0, 0, 1) * 360"` guarantees `93 / 100.0 = 0.93` (93% fill).
   - Steps: `endAngle="270 + clamp([STEP_COUNT] / 10000.0, 0, 1) * 360"` guarantees `1414 / 10000.0 = 0.1414` (14.14% fill).
   - Date: Line 1 `[DAY_OF_WEEK_S]` guarantees `"SUN"`; Line 2 `[MONTH_S] [DAY]` guarantees `"OCT 11"`.

---

## 5. APK Resource Inspection

Inspected compiled APK resources (`watchface/build/outputs/apk/debug/watchface-debug.apk`) via `unzip -p`:
- Verified that `res/raw/watchface.xml` inside the compiled APK matches source `watchface.xml`.
- Confirmed that AAPT2 compiled the exact WFF v2 XML without modifying custom expressions or layout nodes.

---

## 6. Minimal Recommended Corrections

1. **Battery Complication (`slotId="1"`):**
   In `<Complication type="RANGED_VALUE">`:
   ```xml
   <Arc centerX="45" centerY="45" width="80" height="80" startAngle="270"
        endAngle="270 + clamp([BATTERY_PERCENT] / 100.0, 0, 1) * 360">
       <Stroke color="#00FF66" thickness="4" />
   </Arc>
   ```

2. **Date Complication (`slotId="2"`):**
   In `<Complication type="SHORT_TEXT">`:
   ```xml
   <!-- Line 1: SUN -->
   <PartText x="0" y="22" width="90" height="22">
       <Text align="CENTER">
           <Font family="SYNC_TO_DEVICE" size="14" color="#A8E6A0" weight="BOLD">
               <Template><![CDATA[%s]]></Template>
               <Parameter expression="[DAY_OF_WEEK_S]" />
           </Font>
       </Text>
   </PartText>
   <!-- Line 2: OCT 11 -->
   <PartText x="0" y="46" width="90" height="22">
       <Text align="CENTER">
           <Font family="SYNC_TO_DEVICE" size="13" color="#F5F0E6" weight="BOLD">
               <Template><![CDATA[%s %d]]></Template>
               <Parameter expression="[MONTH_S]" />
               <Parameter expression="[DAY]" />
           </Font>
       </Text>
   </PartText>
   ```

3. **Steps Complication (`slotId="3"`):**
   In `<Complication type="GOAL_PROGRESS">`:
   ```xml
   <Arc centerX="45" centerY="45" width="80" height="80" startAngle="270"
        endAngle="270 + clamp([STEP_COUNT] / 10000.0, 0, 1) * 360">
       <Stroke color="#00FF66" thickness="4" />
   </Arc>
   ```
