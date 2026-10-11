# Watch Face Visual Architecture Audit: Google Pixel Watch 5 (45 mm)

## Executive Summary

This document provides a comprehensive visual architecture audit and technical design plan for the **Pixel Watch 5 (45 mm)** custom analog watch face implemented using Google's **Watch Face Format (WFF v2)**.

The objective is to establish a clear architectural roadmap for reproducing a premium, traditional analog watch face appearance while preserving dynamic data bindings, battery efficiency, and Wear OS 5 compatibility.

---

## 1. Current Project Architecture

### 1.1 Project Structure & Build Configuration
- **Root Directory:** `/home/verl/AndroidStudioProjects/VerlWatchFace`
- **Application Module:** `:watchface` (`/home/verl/AndroidStudioProjects/VerlWatchFace/watchface`)
- **Android Gradle Plugin (AGP):** 9.4.1
- **Gradle Version:** 8.13
- **SDK Targets:** `compileSdk = 37`, `minSdk = 36`, `targetSdk = 37`
- **Watch Face Format Version:** WFF Version 2 (`com.google.wear.watchface.format.version = 2`)
- **Executable Code:** None (`android:hasCode="false"` in `AndroidManifest.xml`)

### 1.2 Resource Allocation
- **Manifest:** `watchface/src/main/AndroidManifest.xml`
- **Watch Face Definition:** `watchface/src/main/res/raw/watchface.xml`
- **Metadata Declaration:** `watchface/src/main/res/xml/watch_face_info.xml`
- **Hand Drawables:**
  - `watchface/src/main/res/drawable/hour_hand.xml` (VectorDrawable, 16dp x 150dp)
  - `watchface/src/main/res/drawable/minute_hand.xml` (VectorDrawable, 12dp x 190dp)
  - `watchface/src/main/res/drawable/second_hand.xml` (VectorDrawable, 4dp x 200dp)
- **Preview Asset:** `watchface/src/main/res/drawable/preview.png`
- **String Resources:** `watchface/src/main/res/values/strings.xml`

### 1.3 Canvas & Coordinate System
- **Canonical Canvas Resolution:** `450 x 450` units
- **Center Coordinate:** `(225, 225)`
- **Display Geometry:** Round / Circle (`clipShape="CIRCLE"` or `clipShape="NONE"`)
- **Scaling Mechanism:** WFF automatically scales the 450x450 coordinate space to match the physical screen resolution of the Pixel Watch 5 (480x480 physical pixels at 320 dpi).

---

## 2. Visual Component Inventory

| Component | Source File / Element | Rendering Technique | Dimensions & Position | Colors & Typography | Asset vs. XML | Potential Improvements |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Background** | `watchface.xml`<br>`<Scene>` | Property `backgroundColor` | `450 x 450`<br>`(0, 0)` | `#000000`<br>(Pure Black) | XML Property | Optimal for OLED power efficiency. |
| **Hour Numerals (1-12)** | `watchface.xml`<br>`<PartText>` | WFF Text Primitives | `46 x 32` bounding boxes around R=185px | Warm Ivory `#F5F0E6`<br>`SYNC_TO_DEVICE` size 24 bold | XML Text | Bundle a custom TTF/OTF font in `res/font/` for classic typography. |
| **Hour Markers (12)** | `watchface.xml`<br>`<Group>` / `<Line>` | Rotated XML Lines | `startX="225" startY="6"`<br>`endX="225" endY="18"` | Soft Mint Green `#A8E6A0`<br>Thickness: 3px | XML Primitive | Excellent sharpness; no bitmap assets required. |
| **Minute Markers (48)** | `watchface.xml`<br>`<Group>` / `<Line>` | Rotated XML Lines | `startX="225" startY="8"`<br>`endX="225" endY="14"` | Subtle Gray `#666666`<br>Thickness: 1px | XML Primitive | 48 XML groups add small parse overhead; can be flattened if needed. |
| **Hour Hand** | `watchface.xml`<br>`<HourHand>` | VectorDrawable Reference | `16 x 150`<br>Pivot: `(0.5, 0.9333)` | `#F5F0E6` outer fill<br>`#A8E6A0` inner inlay | VectorDrawable (`hour_hand.xml`) | Custom vector path provides clean tapered sword hand geometry. |
| **Minute Hand** | `watchface.xml`<br>`<MinuteHand>` | VectorDrawable Reference | `12 x 190`<br>Pivot: `(0.5, 0.9210)` | `#F5F0E6` outer fill<br>`#A8E6A0` inner inlay | VectorDrawable (`minute_hand.xml`) | Custom vector path provides elongated tapered hand geometry. |
| **Second Hand** | `watchface.xml`<br>`<SecondHand>` | VectorDrawable Reference | `4 x 200`<br>Pivot: `(0.5, 0.9000)` | Soft Mint Green `#A8E6A0` | VectorDrawable (`second_hand.xml`) | Hidden in Ambient Mode via `<Variant mode="AMBIENT" target="alpha" value="0"/>`. |
| **Center Pivot** | `watchface.xml`<br>`<Group>` / `<Ellipse>` | WFF Shape Primitives | `14 x 14`<br>Center: `(225, 225)` | Outer: `#F5F0E6`<br>Inner: `#A8E6A0` | XML Primitive | Clean dual-ring cap over hand rotation pins. |
| **Battery Complication** | `watchface.xml`<br>`<ComplicationSlot slotId="1">` | WFF Arcs & Text | `90 x 90`<br>Top Center `(180, 60)` | Track: `#1A331A`<br>Arc: `#00FF66`<br>Text: `#F5F0E6` | XML Primitives | Default provider: `WATCH_BATTERY`. Uses dynamic WFF expressions. |
| **Date Complication** | `watchface.xml`<br>`<ComplicationSlot slotId="2">` | WFF Charcoal Arc & Text | `90 x 90`<br>Right Center `(300, 180)` | Border: `#303030`<br>Weekday: `#A8E6A0`<br>Date: `#F5F0E6` | XML Primitives | Default provider: `DATE`. Formatted into 2 rows (Weekday / Month & Day). |
| **Steps Complication** | `watchface.xml`<br>`<ComplicationSlot slotId="3">` | WFF Arcs & Text | `90 x 90`<br>Bottom Center `(180, 300)` | Track: `#1A331A`<br>Arc: `#00FF66`<br>Text: `#F5F0E6` | XML Primitives | Default provider: `STEP_COUNT`. Normalized to a 10,000 step goal, capped at 100%. |
| **Heart Rate Complication** | `watchface.xml`<br>`<ComplicationSlot slotId="4">` | WFF Charcoal Arc & Text | `90 x 90`<br>Left Center `(60, 180)` | Border: `#303030`<br>Accent Arc: `#FF4055`<br>Text: `#F5F0E6` | XML Primitives | Default provider: `HEART_RATE`. Includes small red heart icon (`♥`). |

---

## 3. Watch Face Format (WFF v2) Capability Assessment

### 3.1 Supported Asset Formats & Vector Restrictions
- **VectorDrawable (`.xml`):** Fully supported in WFF via `@drawable/filename` references for `<HourHand>`, `<MinuteHand>`, `<SecondHand>`, and `<Image>`. Vectors must use standard Android VectorDrawable syntax (`<vector>`, `<path android:fillColor="..." android:pathData="..."/>`). Complex features such as gradients (`<gradient>`) or animated vectors (`<animated-vector>`) are **not** supported in WFF hand elements.
- **Bitmaps (`.png` / `.jpg`):** Native support for raster PNG files. Recommended for complex textures, metallic bevels, or pre-rendered dial background artwork.
- **SVG Files (`.svg`):** **Not directly parsed at runtime by WFF.** Any SVG source design must be converted into an Android VectorDrawable XML file or rasterized to a PNG image before inclusion in `res/drawable/`.

### 3.2 Clock Hand Architecture
WFF schema validator strictly mandates that `<HourHand>`, `<MinuteHand>`, and `<SecondHand>` elements **must** specify a `resource="..."` attribute pointing to a drawable resource. Direct WFF shape primitives (`<PartDraw>`, `<Line>`, `<Rectangle>`) inside clock hand tags are rejected by AAPT2/WFF validation.

### 3.3 Dynamic Expressions & Arc Calculations
WFF Version 2 supports comprehensive mathematical expressions in element attributes (`startAngle`, `endAngle`, `alpha`, `color`):
- Arithmetic operators: `+`, `-`, `*`, `/`, `%`
- Math functions: `clamp(val, min, max)`, `min(a, b)`, `max(a, b)`, `round(x)`, `floor(x)`, `ceil(x)`
- Conditionals: Ternary `condition ? val1 : val2`
- System Data Sources: `[BATTERY_PERCENT]`, `[STEP_COUNT]`, `[STEP_GOAL]`, `[HEART_RATE]`, `[DAY_OF_WEEK_S]`, `[MONTH_S]`, `[DAY]`
- Complication Data Sources: `[COMPLICATION.RANGED_VALUE_VALUE]`, `[COMPLICATION.GOAL_PROGRESS_VALUE]`, `[COMPLICATION.TEXT]`, `[COMPLICATION.TITLE]`

### 3.4 Custom Fonts
WFF `<Font>` tags support system fonts via `family="SYNC_TO_DEVICE"`. TrueType (`.ttf`) or OpenType (`.otf`) font files placed in `res/font/` can be referenced using `family="@font/font_name"`.

### 3.5 Layering, Order, and Ambient Mode
- **Layer Order:** WFF renders elements strictly in XML top-to-bottom order within `<Scene>`. Clock hands (`<AnalogClock>`) are placed after complications so hands sweep over the complications.
- **Ambient Mode (AOD):** Managed via `<Variant mode="AMBIENT" target="alpha" value="0"/>` or target color modifications to enforce low pixel ratio and energy savings.

---

## 4. Visual Difference Analysis & Root Causes

| Visual Difference / Issue | Root Cause | Classification | Corrective Strategy |
| :--- | :--- | :--- | :--- |
| **Cyan / Cold Blue Tones** | Original template defaulted to system font tints or unstyled text attributes. | Incorrect Styling | Explicitly set `#F5F0E6` (Warm Ivory) on hour numerals and `#A8E6A0` (Mint Green) on accents. |
| **Thin, Boxy Clock Hands** | Template used basic rectangular lines. WFF requires hand resources. | Resource Architecture | Created custom tapered VectorDrawables (`hour_hand.xml`, `minute_hand.xml`) with warm ivory fill and mint green inlays. |
| **Missing Battery Complication** | Initial `defaultSystemProvider="BATTERY"` used an invalid system constant name (`"WATCH_BATTERY"` is required). | Manifest / XML Constant Error | Fixed provider string to `WATCH_BATTERY` (`SystemDataSources.DATA_SOURCE_WATCH_BATTERY` = ID 1). |
| **Static / Full 360° Progress Rings** | `defaultSystemProviderType="SHORT_TEXT"` was specified for Steps, matching a `SHORT_TEXT` block with a static 360° arc. | Logic & Type Mismatch | Set `defaultSystemProviderType="GOAL_PROGRESS"` and applied `clamp([COMPLICATION.GOAL_PROGRESS_VALUE] / 10000.0, 0, 1) * 360`. |
| **Wrapped / Overflowing Step Arcs** | Goal progress values > 10,000 steps wrapped past 360° due to unclamped division. | Math Expression Error | Applied WFF `clamp(..., 0, 1)` function in `endAngle` expression. |
| **Small Unreadable Complication Text** | Font sizes were set to 10-12px in 90x90 bounding boxes. | Typography Scaling | Scaled primary values to 16-17px bold and adjusted line heights. |

---

## 5. Recommended Rendering Approach per Component

1. **Background (`<Scene>`):**
   - **Approach:** **Classification A (Modify Existing WFF XML)**
   - **Justification:** `backgroundColor="#000000"` provides pure black OLED power efficiency without bitmap overhead.

2. **Hour Numerals (1-12):**
   - **Approach:** **Classification A / C (Modify WFF XML / Optional Font Asset)**
   - **Justification:** WFF `<PartText>` primitives with `#F5F0E6` warm ivory tint and size 24 bold weight deliver high legibility. A custom font asset can be added in `res/font/` if a serif typography look is desired.

3. **Hour & Minute Dial Ticks:**
   - **Approach:** **Classification A (Modify Existing WFF XML)**
   - **Justification:** XML `<Line>` shapes with `#A8E6A0` (major) and `#666666` (minor) render vector-crisp lines at all display densities.

4. **Hour, Minute, and Second Hands:**
   - **Approach:** **Classification B (Replace with Custom Graphical Assets)**
   - **Justification:** WFF schema requires `resource="..."` on hand elements. VectorDrawables in `res/drawable/` enable custom tapered geometry, inlays, and precise rotation pivots.

5. **Center Pivot Cap:**
   - **Approach:** **Classification A (Modify Existing WFF XML)**
   - **Justification:** WFF `<Ellipse>` primitives draw a crisp dual-layer center hub (`#F5F0E6` outer, `#A8E6A0` inner).

6. **Complications (Battery, Date, Steps, Heart Rate):**
   - **Approach:** **Classification A (Modify Existing WFF XML)**
   - **Justification:** Native WFF `<ComplicationSlot>`, `<Arc>`, and `<PartText>` elements provide dynamic data binding, standard Wear OS system providers, and user customization support (`Editable="true"`).

---

## 6. Custom Asset Specifications

### 6.1 `res/drawable/hour_hand.xml`
- **Purpose:** Tapered sword hour hand graphic with inlay.
- **Format:** Android VectorDrawable XML (`<vector>`).
- **Dimensions:** Width `16dp`, Height `150dp` (Viewport: `16 x 150`).
- **Pivot:** `pivotX="0.5"`, `pivotY="0.9333"` (Pivot point at Y=140dp on graphic, placing rotation exactly at screen center `225, 225`).
- **Color Layers:**
  - Outer Path: Warm Ivory `#F5F0E6`
  - Inner Inlay Path: Soft Mint Green `#A8E6A0`

### 6.2 `res/drawable/minute_hand.xml`
- **Purpose:** Elongated tapered minute hand graphic with inlay.
- **Format:** Android VectorDrawable XML (`<vector>`).
- **Dimensions:** Width `12dp`, Height `190dp` (Viewport: `12 x 190`).
- **Pivot:** `pivotX="0.5"`, `pivotY="0.9210"` (Pivot point at Y=175dp on graphic, placing rotation exactly at screen center `225, 225`).
- **Color Layers:**
  - Outer Path: Warm Ivory `#F5F0E6`
  - Inner Inlay Path: Soft Mint Green `#A8E6A0`

### 6.3 `res/drawable/second_hand.xml`
- **Purpose:** Thin green second hand graphic.
- **Format:** Android VectorDrawable XML (`<vector>`).
- **Dimensions:** Width `4dp`, Height `200dp` (Viewport: `4 x 200`).
- **Pivot:** `pivotX="0.5"`, `pivotY="0.9000"` (Pivot point at Y=180dp on graphic, placing rotation exactly at screen center `225, 225`).
- **Color Layers:**
  - Main Stroke: Soft Mint Green `#A8E6A0`
- **Ambient Variant:** Hidden in AOD mode (`alpha="0"`).

### 6.4 `res/drawable/preview.png`
- **Purpose:** Preview image shown in the Wear OS watch face selector.
- **Format:** PNG with transparency.
- **Dimensions:** `450 x 450` pixels.

---

## 7. Prioritized Implementation Plan

### Stage 1: Dial & Typography Refinement
- **Files Affected:** `watchface/src/main/res/raw/watchface.xml`
- **Objective:** Ensure warm ivory tone (`#F5F0E6`), size 24 bold weight for hour numerals 1-12, mint green hour ticks (`#A8E6A0`), and thin minute ticks (`#666666`).
- **Validation:** Run `:watchface:assembleDebug` and inspect XML validation.

### Stage 2: Hand Graphic Assets & Center Hub Alignment
- **Files Affected:** `res/drawable/hour_hand.xml`, `res/drawable/minute_hand.xml`, `res/drawable/second_hand.xml`, `watchface.xml`
- **Objective:** Verify tapered baton vector drawables, mint green inlays (`#A8E6A0`), and center hub alignment at `(225, 225)`.
- **Validation:** Build and verify pivot accuracy on Pixel Watch 5 display.

### Stage 3: Complication Arc Normalization & Formatting
- **Files Affected:** `watchface/src/main/res/raw/watchface.xml`
- **Objective:** Verify `WATCH_BATTERY`, `DATE`, `STEP_COUNT`, and `HEART_RATE` system provider bindings. Verify dynamic progress arc formulas using `clamp(...)` starting at 12 o'clock (`270°`).
- **Validation:** Check `dumpsys activity service com.google.wear.watchface.runtime` on device for active data source IDs (`1`, `2`, `4`, `17`).

### Stage 4: Ambient Mode & Final On-Device Inspection
- **Files Affected:** `watchface/src/main/res/raw/watchface.xml`
- **Objective:** Verify Always-On Display (AOD) ambient mode transitions, second hand hiding (`alpha="0"`), and OLED black background power optimization.
- **Validation:** Test ambient mode on connected Pixel Watch 5 device.

---

## 8. Technical Risks and Limitations

1. **WFF VectorDrawable Syntax Restrictions:**
   WFF handles standard `<path>` fill and stroke attributes, but does not support advanced vector features like gradients or animated paths. All hand graphics must use solid fills (`#F5F0E6`, `#A8E6A0`).

2. **System Font Dependency:**
   When using `family="SYNC_TO_DEVICE"`, exact font rendering relies on the system font installed on the Wear OS device. If exact typographic styling is required, a font file must be bundled in `res/font/`.

3. **Wear OS Persistent Complication Cache:**
   When an updated watch face is deployed via `installDebug`, Wear OS preserves existing user complication selections per watch face instance (`wfId-13`). If a slot was previously unconfigured, the user can re-select the provider in the watch face editor, or application state can be reset (`adb shell pm clear com.example.verlwatchface`) to trigger default provider binding.

---

## 9. Verification & References

### Build & Deployment Verification
- **Gradle Tasks:** `:watchface:assembleDebug`, `:watchface:installDebug`
- **Device Target:** Google Pixel Watch 5 (45 mm)
- **Validation Tooling:** AAPT2 WFF Schema Validator & `analyze_file`

### Key Reference Documentation
- [Android Watch Face Format Setup](https://developer.android.com/training/wearables/wff/setup)
- [WFF Time and Analog Clocks](https://developer.android.com/training/wearables/wff/time)
- [WFF Complications Guide](https://developer.android.com/training/wearables/wff/complications)
