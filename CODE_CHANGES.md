# SafeRoute Map Redesign - Code Changes Reference

## Files Modified

### 1. lib/app.dart
**Change**: Modified app home navigation to load MapPickerScreen instead of HomeScreen

**Before**:
```dart
import 'screens/home_screen.dart';

// ... in build method ...
home: _isCheckingSession
    ? const SplashScreen()
    : (_session == null
          ? AuthScreen(...)
          : HomeScreen(
              user: _session!.user,
              onSignOut: _onSignOut,
              localeCode: _localeCode,
              onLocaleChanged: _onLocaleChanged,
              themeMode: _themeMode,
              onThemeModeChanged: _onThemeModeChanged,
            )),
```

**After**:
```dart
import 'screens/map_picker_screen.dart';

// ... in build method ...
home: _isCheckingSession
    ? const SplashScreen()
    : (_session == null
          ? AuthScreen(
              localeCode: _localeCode,
              onAuthenticated: _onAuthenticated,
            )
          : MapPickerScreen(
              userId: _session!.user.id,
              initialTransportMode: null,
            )),
```

**Impact**: Users now go directly to map screen after authentication instead of landing page

---

### 2. lib/screens/map_picker_screen.dart
**Changes**: 
- Updated polyline colors (blue for selected, green for safest)
- Removed time-based route information
- Added transport mode filter chips

#### Change 2a: Polyline Colors
**Before**:
```dart
polylines: {
  for (var index = 0; index < _routeOptions.length; index++)
    gmaps.Polyline(
      polylineId: gmaps.PolylineId('option_$index'),
      points: _routeOptions[index].points.map(_toGoogleLatLng).toList(),
      width: (_selectedRouteIndex == index || _bestRouteIndex == index)
          ? 5
          : 3,
      color: _selectedRouteIndex == index
          ? Colors.blueAccent
          : (_bestRouteIndex == index
                ? const Color(0xFF0E7C7B).withValues(alpha: 0.95)
                : Colors.grey.shade500.withValues(alpha: 0.7)),
    ),
},
```

**After**:
```dart
polylines: {
  for (var index = 0; index < _routeOptions.length; index++)
    gmaps.Polyline(
      polylineId: gmaps.PolylineId('option_$index'),
      points: _routeOptions[index].points.map(_toGoogleLatLng).toList(),
      width: (_selectedRouteIndex == index)
          ? 6
          : (_bestRouteIndex == index ? 5 : 3),
      color: _selectedRouteIndex == index
          ? Colors.blueAccent
          : (_bestRouteIndex == index
                ? Colors.green.shade400
                : Colors.grey.shade400.withValues(alpha: 0.6)),
    ),
},
```

**Changes**:
- Selected route: width 5px → 6px
- Selected route color: kept Colors.blueAccent
- Safest route color: Color(0xFF0E7C7B) → Colors.green.shade400
- Alternative routes color: grey.shade500 → grey.shade400 with reduced opacity

#### Change 2b: Route List Item Display Text
**Before**:
```dart
Text(
  'Safety ${_routeOptions[i].safetyScore.toStringAsFixed(0)} • ${_formatDistance(_routeOptions[i].totalDistance)} • ETA ${_formatDuration(_routeOptions[i].safetyAdjustedDuration)} (base ${_formatDuration(_routeOptions[i].totalDuration)})',
  style: TextStyle(
    fontSize: 12,
    color: isDark
        ? Colors.white.withValues(alpha: 0.72)
        : null,
  ),
),
```

**After**:
```dart
Text(
  'Safety ${_routeOptions[i].safetyScore.toStringAsFixed(0)} • ${_formatDistance(_routeOptions[i].totalDistance)}',
  style: TextStyle(
    fontSize: 12,
    color: isDark
        ? Colors.white.withValues(alpha: 0.72)
        : null,
  ),
),
```

**Changes**: Removed ETA and base duration, kept only safety score and distance

#### Change 2c: Confirmation Sheet Route Details
**Before**:
```dart
Text('Distance: ${_formatDistance(option.totalDistance)}'),
Text('Base duration: ${_formatDuration(option.totalDuration)}'),
Text(
  'Safety-adjusted ETA: ${_formatDuration(option.safetyAdjustedDuration)}',
),
```

**After**:
```dart
Text('Distance: ${_formatDistance(option.totalDistance)}'),
```

**Changes**: Removed all time-based metrics

#### Change 2d: Transport Mode Filter Chips
**Before**:
```dart
Text(
  'Route Suggestions',
  style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
),
const SizedBox(height: 8),
for (var i = 0; i < _routeOptions.length; i++)
  InkWell(
```

**After**:
```dart
Text(
  'Route Suggestions',
  style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
),
const SizedBox(height: 8),
// Transport mode selector like Google Maps
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      for (final mode in ['Bus', 'Taxi', 'Motorcycle'])
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: FilterChip(
            label: Text(mode),
            selected: _selectedTransportMode?.toLowerCase() == mode.toLowerCase(),
            onSelected: (_) {
              setState(() {
                _selectedTransportMode = mode.toLowerCase();
              });
            },
          ),
        ),
    ],
  ),
),
for (var i = 0; i < _routeOptions.length; i++)
  InkWell(
```

**Changes**: Added horizontal scrollable row with 3 FilterChips for Bus, Taxi, and Motorcycle

---

### 3. lib/screens/route_recorder_screen.dart
**Change**: Updated navigation polyline colors - green for covered distance, blue for remaining

**Before**:
```dart
polylines: {
  // planned traveled segment (already passed on planned path)
  if (plannedTraveled.length > 1)
    gmaps.Polyline(
      polylineId: const gmaps.PolylineId('planned_traveled'),
      points: plannedTraveled,
      width: 6,
      color: Colors.grey.shade400,
    ),
  // planned remaining segment (the safest suggested route ahead)
  if (plannedRemaining.length > 1)
    gmaps.Polyline(
      polylineId: const gmaps.PolylineId('planned_remaining'),
      points: plannedRemaining,
      width: 6,
      color: const Color(0xFF0E7C7B),
    ),
  // actual recorded route (what the user has traveled)
  if (routePolylinePoints.length > 1)
    gmaps.Polyline(
      polylineId: const gmaps.PolylineId('recorded_route'),
      points: routePolylinePoints.map(_toGoogleLatLng).toList(),
      width: 5,
      color: Colors.blueAccent,
    ),
},
```

**After**:
```dart
polylines: {
  // planned traveled segment (already passed - show in green)
  if (plannedTraveled.length > 1)
    gmaps.Polyline(
      polylineId: const gmaps.PolylineId('planned_traveled'),
      points: plannedTraveled,
      width: 6,
      color: Colors.green.shade400,
    ),
  // planned remaining segment (the safest suggested route ahead - show in blue)
  if (plannedRemaining.length > 1)
    gmaps.Polyline(
      polylineId: const gmaps.PolylineId('planned_remaining'),
      points: plannedRemaining,
      width: 6,
      color: Colors.blueAccent,
    ),
  // actual recorded route (what the user has traveled - show in blue)
  if (routePolylinePoints.length > 1)
    gmaps.Polyline(
      polylineId: const gmaps.PolylineId('recorded_route'),
      points: routePolylinePoints.map(_toGoogleLatLng).toList(),
      width: 5,
      color: Colors.blueAccent,
    ),
},
```

**Changes**:
- Planned traveled: Colors.grey.shade400 → Colors.green.shade400
- Planned remaining: Color(0xFF0E7C7B) → Colors.blueAccent
- Recorded route: kept Colors.blueAccent

**Impact**: Users can visually track progress (green for covered, blue for remaining)

---

## Summary of Code Changes

| File | Type | Impact |
|------|------|--------|
| app.dart | Navigation | Direct to map screen |
| map_picker_screen.dart | Colors | Blue selected, green safest |
| map_picker_screen.dart | Display | Removed time metrics |
| map_picker_screen.dart | UI | Added transport filters |
| route_recorder_screen.dart | Navigation | Green/blue progress tracking |

## Testing Checklist

- [ ] App launches directly to map screen after login
- [ ] Multiple routes visible on map simultaneously
- [ ] Blue polyline = selected route
- [ ] Green polyline = safest route
- [ ] Gray polylines = alternatives
- [ ] Transport mode filter chips (Bus/Taxi/Motorcycle) toggle correctly
- [ ] Route list shows only safety score and distance
- [ ] Confirmation sheet displays safety/distance only
- [ ] During navigation, green shows covered distance
- [ ] During navigation, blue shows remaining route
- [ ] No compilation errors
- [ ] App runs without crashes on test device

## Rollback Plan

If issues arise, revert these files to their original versions:
1. git checkout lib/app.dart
2. git checkout lib/screens/map_picker_screen.dart
3. git checkout lib/screens/route_recorder_screen.dart
