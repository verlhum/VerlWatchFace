# Clock-Hand Rendering Hierarchy & Complication Masking Report

## Overview
This document details the architectural rendering hierarchy reorganization implemented in **`watchface/src/main/res/raw/watchface.xml`** for the **Pixel Watch 5 (45 mm)** Watch Face Format (WFF v2) project.

Previously, clock hands rendered on top of complication slots, causing the minute and second hands to cross over and obscure complication text (e.g. date string "Oct 11" and step count).

---

## 1. Reorganized WFF Rendering Hierarchy

In Watch Face Format (WFF v2), elements inside `<Scene>` render in **top-to-bottom XML sequence**. Elements declared later in the XML render on top of earlier elements.

The XML structure has been reorganized into four distinct rendering layers:

```
+-------------------------------------------------------------------+
| LAYER 4: CENTER CAP / HUB                                         |
| Group name="center_cap" (217, 217)                                |
+-------------------------------------------------------------------+
| LAYER 3: COMPLICATION SLOTS (With Opaque OLED Black Disc)         |
| Slot 1 (Battery), Slot 2 (Date), Slot 3 (Steps), Slot 4 (HR)      |
+-------------------------------------------------------------------+
| LAYER 2: ANALOG CLOCK HANDS                                       |
| AnalogClock -> HourHand, MinuteHand, SecondHand                   |
+-------------------------------------------------------------------+
| LAYER 1: DIAL BACKGROUND & MARKERS                                |
| Major/Minor Ticks, Hour Numerals (1..12)                          |
+-------------------------------------------------------------------+
```

1. **Layer 1 (Dial Background & Markers):** Major ticks (`#A8E6A0`), minor ticks (`#666666`), and traditional hour numerals 1..12 (`#F5F0E6`).
2. **Layer 2 (Analog Clock Hands):** `<AnalogClock>` containing `<HourHand>`, `<MinuteHand>`, and `<SecondHand>`. Hands sweep above the dial background but **underneath** the complication slots.
3. **Layer 3 (Opaque Complication Slots):**
   Each `<ComplicationSlot>` and `<Complication type="...">` block begins with an **opaque `#000000` black disc**:
   ```xml
   <PartDraw x="0" y="0" width="90" height="90">
       <Ellipse x="5" y="5" width="80" height="80">
           <Fill color="#000000" />
       </Ellipse>
   </PartDraw>
   ```
   This disc masks out the clock hand segment passing behind the complication slot while maintaining the pure OLED black background. The track/border (`#1A331A` / `#303030`), progress arcs (`#00FF66`), icons, and text render on top of the black disc.
4. **Layer 4 (Center Pivot Cap):** `<Group name="center_cap">` renders on top at `(225, 225)`.

---

## 2. Exact XML Modifications (`watchface/src/main/res/raw/watchface.xml`)

1. **Moved `<AnalogClock>`:** Relocated from line ~635 to immediately follow the hour numerals (Layer 2), before the `<ComplicationSlot>` elements.
2. **Moved `<Group name="center_cap">`:** Positioned as the final element in `<Scene>` (Layer 4) to ensure the dual-ring hub remains visible above hands.
3. **Added Opaque Masking Discs:** Added `<Ellipse x="5" y="5" width="80" height="80"><Fill color="#000000" /></Ellipse>` inside `PartDraw x="0" y="0" width="90" height="90"` across all `RANGED_VALUE`, `GOAL_PROGRESS`, `SHORT_TEXT`, and `EMPTY` complication branches across slots 1, 2, 3, and 4.

---

## 3. Preserved Properties
- **Hand Geometry, Pivots & Rotation:** Preserved `hour_hand.xml`, `minute_hand.xml`, `second_hand.xml`, vector dimensions, pivots, and rotation centers `(225.0, 225.0)`.
- **Complication Expressions & Data Providers:** Preserved dynamic `[BATTERY_PERCENT]` and `[STEP_COUNT]` formulas, `[DAY_OF_WEEK_S]` / `[MONTH_S] [DAY]` date formatting, and system provider bindings.
- **Colors & Styling:** Preserved warm ivory (`#F5F0E6`), mint green (`#A8E6A0`), charcoal (`#303030`), red accent (`#FF4055`), and OLED black (`#000000`).
