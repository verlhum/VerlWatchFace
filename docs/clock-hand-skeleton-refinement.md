# Skeleton Clock-Hand Refinement Report

## Overview
This document details the skeletonized clock-hand visual refinement pass implemented on the **Pixel Watch 5 (45 mm)** custom Watch Face Format (WFF v2) project.

In previous iterations, rendering clock hands behind opaque complication discs made the hands appear disconnected when passing behind the complication circles. To restore visual continuity across the entire 450x450 dial, the clock hands were redesigned as **skeletonized baton hands with thin warm ivory outlines and subtle mint-green axis lines**, and restored to render **on top of the complications**.

---

## 1. Vector Drawable Refinements

### 1.1 Hour Hand (`watchface/src/main/res/drawable/hour_hand.xml`)
- **Structure:**
  - Outer warm ivory outline: `<path android:strokeColor="#F5F0E6" android:strokeWidth="1.5" android:pathData="..." />`
  - Inner mint-green axis line: `<path android:strokeColor="#A8E6A0" android:strokeWidth="1.0" android:pathData="M10,22 L10,132" />`
- **Visual Effect:** Visually heavy baton outline (`width="20"`) with a hollow interior. Complication numbers and text underneath remain 100% visible and readable through the open interior.

### 1.2 Minute Hand (`watchface/src/main/res/drawable/minute_hand.xml`)
- **Structure:**
  - Outer warm ivory outline: `<path android:strokeColor="#F5F0E6" android:strokeWidth="1.5" android:pathData="..." />`
  - Inner mint-green axis line: `<path android:strokeColor="#A8E6A0" android:strokeWidth="1.0" android:pathData="M7,18 L7,165" />`
- **Visual Effect:** Narrower baton outline (`width="14"`) with a hollow interior, maintaining visual distinction from the hour hand.

### 1.3 Second Hand (`watchface/src/main/res/drawable/second_hand.xml`)
- Preserved single thin mint-green needle path (`width="4"`) with a counterbalance bulb. Hidden in Ambient mode.

---

## 2. Reorganized Rendering Order (`watchface/src/main/res/raw/watchface.xml`)

1. **Removed Masking Discs:** Removed the opaque black filled ellipses from all complication slot type branches.
2. **Restored Layer Hierarchy:**
   - **Layer 1:** Dial Background, Tick Marks, and Numerals (1..12).
   - **Layer 2:** Four Complication Slots (Battery, Date, Steps, Heart Rate).
   - **Layer 3:** Analog Clock Hands (`<AnalogClock>`). Hands pass ON TOP of complications continuously.
   - **Layer 4:** Center Pivot Cap (`<Group name="center_cap">`) at `(225, 225)`.

---

## 3. Vector Rendering Compatibility Notes
- WFF v2 supports standard Android VectorDrawable stroke attributes (`android:strokeColor`, `android:strokeWidth`, `android:strokeLineCap`, `android:strokeLineJoin`).
- Omitting `android:fillColor` defaults path fill to transparent, creating hollow skeletonized geometry that preserves underlying readability without obscuring text.

---

## 4. Build, Validation & Deployment Results
- **Gradle Build Task:** `:watchface:installDebug` — **BUILD SUCCESSFUL (Exit Code 0)**.
- **WFF XML Schema Analyzer:** **0 errors**.
- **Deployment Status:** Successfully deployed and active on **Google Pixel Watch 5**.
