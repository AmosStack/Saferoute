# SafeRoute Map UI - Visual Design Guide

## Color Coding System

### Route Selection Screen (Map Picker)
```
┌─────────────────────────────────────────┐
│         SafeRoute Map Screen            │
├─────────────────────────────────────────┤
│                                         │
│            [  Google Map  ]             │
│                                         │
│  ┌─ Blue Path (Thick)                  │  ← Selected Route
│  ├─ Green Path (Medium)                │  ← Safest Route  
│  ├─ Gray Path (Thin)                   │  ← Alternative
│  └─ Gray Path (Thin)                   │  ← Alternative
│                                         │
├─────────────────────────────────────────┤
│  Route Suggestions                      │
│  [Bus] [Taxi] [Motorcycle]             │  ← Transport Mode Filter
│                                         │
│  🟦 Taxi Route (Safest)                │  
│    Safety 92 • 5.2 km                  │
│                                         │
│  🟥 Bus Route                          │
│    Safety 85 • 4.8 km                  │
│                                         │
│  🟩 Motorcycle Route                   │
│    Safety 78 • 6.1 km                  │
│                                         │
├─────────────────────────────────────────┤
│         [▶ Start Route]                 │
└─────────────────────────────────────────┘
```

### Route Confirmation Sheet
```
┌────────────────────────────┐
│     Confirm Route          │
├────────────────────────────┤
│ From: Kariakoo             │
│ To: University             │
│                            │
│ Route: Taxi Route          │
│ Safety score: 92 / 100     │
│ Distance: 5.2 km           │
│                            │
│ Bus stops: Available       │
│                            │
│ Available Modes            │
│ [Bus] [Taxi] [Motorcycle]  │
│                            │
│        [✓ Start]           │
└────────────────────────────┘
```

### Active Navigation Screen (Route Recorder)
```
┌─────────────────────────────────────────┐
│      Navigation in Progress             │
├─────────────────────────────────────────┤
│                                         │
│            [  Google Map  ]             │
│                                         │
│  🟢🟢🟢🟢 Covered (Green)             │
│  🟦🟦🟦🟦 Remaining (Blue)            │
│  🟦🟦🟦   Recorded Track (Blue)       │
│                                         │
│  📍 Current Location                   │
│                                         │
├─────────────────────────────────────────┤
│ Distance Traveled: 2.1 km / 5.2 km     │
│ Time Remaining: ~8 mins                │
│ Status: On Route                       │
│                                         │
│ [🎙 SOS] [⚠️ Report] [⏹ Stop]          │
└─────────────────────────────────────────┘
```

## Color Reference

### Map Polylines
| Element | Color | RGB | Opacity | Width | Usage |
|---------|-------|-----|---------|-------|-------|
| Selected Route | Blue Accent | #2196F3 | 100% | 6px | Currently selected path |
| Safest Route | Green 400 | #66BB6A | 100% | 5px | Best safety option |
| Alternative Routes | Gray 400 | #BDBDBD | 60% | 3px | Other options |
| Covered Distance | Green 400 | #66BB6A | 100% | 6px | Traveled segment |
| Remaining Route | Blue Accent | #2196F3 | 100% | 6px | Path ahead |
| Recorded Track | Blue Accent | #2196F3 | 100% | 5px | Actual user path |

### Key Indicators
- **Blue** = User's chosen/active route
- **Green** = Safety focused / Progress made
- **Gray** = Secondary options

## Route Information Display

### Before Changes
```
Taxi Route
Safety 92 • 5.2 km • ETA 12 mins (base 8 mins)
```

### After Changes
```
Taxi Route (Safest)
Safety 92 • 5.2 km
```

**Why**: Focus on safety metrics over time-based decisions

## Transport Mode Selector

### Placement
- Location: Route Suggestions panel header
- Style: Filter Chips (Material Design 3)
- Modes: Bus, Taxi, Motorcycle
- Selection: Single or multiple (toggleable)

### Behavior
```
Inactive Chip:
┌──────────┐
│   Bus    │  (gray background, gray border)
└──────────┘

Active Chip:
┌──────────┐
│✓  Taxi   │  (teal background, bold text)
└──────────┘
```

## User Flow Changes

### Previous Experience
```
Login 
  ↓
Home Screen
  ├─ Select Transport Mode
  └─ Click "Start Route"
    ↓
Map Screen (with single route)
    ↓
See best route + alternatives
```

### New Experience
```
Login
  ↓
Map Screen (Multiple routes visible immediately)
  ├─ Blue route = Selected
  ├─ Green route = Safest
  ├─ Gray routes = Alternatives
  ├─ Can toggle [Bus] [Taxi] [Motorcycle]
  ├─ Can tap any route to select
  └─ Safety score prominently displayed
    ↓
Click [Start Route]
    ↓
Navigation begins with coverage tracking
```

## Safety Score Visualization

### Score Interpretation
```
90-100: Excellent (Safest) - Dark Green indicator
75-89:  Good              - Light Green indicator  
60-74:  Fair              - Yellow indicator
45-59:  Poor              - Orange indicator
0-44:   Very Poor         - Red indicator
```

### Display in Routes
```
🟢 Taxi Route (Safest)     ← Green = Highest score
   Safety 92 • 5.2 km

🟡 Bus Route               ← Yellow = Medium-high
   Safety 76 • 4.8 km

🔴 Walking Route           ← Red = Lower score
   Safety 48 • 3.2 km
```

## Responsive Design Considerations

### Mobile (Small Screens)
- Route Suggestions panel: Scrollable, compact
- Map: Full screen with floating panels
- Transport filters: Horizontal scroll

### Tablet (Medium Screens)
- Side panel with routes (if space available)
- Larger touch targets for filter chips
- More spacing around elements

### Desktop (Large Screens)
- Split view: Map on left, routes on right
- All routes visible in list simultaneously
- Transport mode selector as button group

## Accessibility

### Color Contrast
- Blue on white: ✓ WCAG AA compliant
- Green on white: ✓ WCAG AA compliant
- Gray on white: May need review

### Labels
- All filter chips have text labels (not just color)
- Route selection uses both color and text
- Status indicators use text + color combo

### Touch Targets
- Filter chips: Minimum 48x48dp (Material Design)
- Route list items: Minimum 48dp height
- Map markers: Minimum 48x48dp

## Example Safety Score Comparison

### Multi-Route View (What Users See Now)
```
ROUTE SUGGESTIONS

[🔴 Bus]  [🟦 Taxi]  [🏍️ Motorcycle]  ← Transport filters

🟦 Taxi Route (Safest) ✓
   Safety 92 • 5.2 km

🟥 Bus Route
   Safety 76 • 4.8 km

🟩 Motorcycle Route
   Safety 65 • 6.1 km

[NEARBY ROUTES - Can swipe to view more]
```

### Key Differences from Before
1. **No time information** - All time metrics removed
2. **Multiple routes always visible** - Don't need to wait for alternatives
3. **Safety is first** - Score displayed prominently
4. **Transport filters** - Quick mode switching (Bus/Taxi/Motorcycle)
5. **Visual hierarchy** - Safest route highlighted in green

## Implementation Details

### Route List Item Structure
```dart
InkWell(
  onTap: () { /* Select this route */ },
  child: Container(
    decoration: BoxDecoration(
      border: Border(
        left: 4px blue (if selected)
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text("Taxi Route (Safest)"),
        ),
        Text("Safety 92 • 5.2 km"),
      ],
    ),
  ),
);
```

### Polyline Color Logic
```dart
color: _selectedRouteIndex == index
    ? Colors.blueAccent         // User selected
    : (_bestRouteIndex == index
        ? Colors.green.shade400  // Safest
        : Colors.grey.shade400)  // Alternatives
```
