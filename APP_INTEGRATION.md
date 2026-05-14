# SafeRoute App Integration Guide

Complete guide to how the Flutter app integrates with the PostgreSQL database and multi-modal transport routing.

## Data Flow Architecture

```
User Action (Flutter App)
    ↓
MapPickerScreen (route selection & transport mode)
    ↓
RoutePathPlannerService (calculates path with bus stops if needed)
    ↓
Backend API (saves data via BackendService)
    ↓
PostgreSQL Database
    └─ users, routes, travel_logs, safety_reports, incidents
```

## Key Features Implemented

### 1. **Multi-Modal Transport Path Planning**

When a user selects a transport mode, the app intelligently calculates the best path:

#### Non-Bus Modes
- **Walking**: Direct walking route using OSRM foot profile
- **Bicycle**: Cycling route using OSRM bike profile  
- **Car/Taxi/Motorcycle/Tricycle**: Driving route using OSRM driving profile

#### Bus Mode (Special Handling)
For bus journeys, the app:

1. **Finds nearest bus stop** to starting location (500m radius)
   - Uses Nominatim (OpenStreetMap) API
   - Query: `amenity=bus_stop`

2. **Creates 3-segment route**:
   - **Segment 1 (Walking)**: Start → Nearest bus stop
   - **Segment 2 (Bus)**: Bus stop A → Bus stop B  
   - **Segment 3 (Walking)**: Nearest bus stop → Destination

3. **Displays color-coded path**:
   - 🟢 Green = Walking
   - 🟣 Purple = Bus
   - 🟠 Orange = Bicycle
   - 🔵 Blue = Driving

4. **Shows segment details**:
   ```
   WALKING: 0.50km, 5min
   BUS: 5.00km, 15min
   WALKING: 0.25km, 2min
   Total: 5.75km, 22min
   ```

### 2. **Database Integration**

All journey data flows to PostgreSQL:

#### Flow 1: Route Recording → Backend
```
RouteRecorderScreen
  ↓ (user completes journey)
Collect: GPS trace, rating, notes, transport mode
  ↓
Save to recorded_routes table
  ↓
Auto-create travel_log entry
  ↓
If safety concerns detected → create safety_report
```

#### Flow 2: Authentication
```
AuthScreen
  ↓ (user registers/logs in)
BackendService.register/login
  ↓
Validates with users table
  ↓
Returns session token
  ↓
Store locally with SharedPreferences
```

#### Flow 3: Data Storage
```
Route completion
  ├─ recorded_routes: GPS trace + metadata
  ├─ travel_logs: journey summary
  ├─ transport_modes: mode type (bus, walking, etc)
  └─ safety_reports: if safety concerns noted
```

### 3. **Service Architecture**

#### **BackendService** - API Communication
- **Authentication**: `register()`, `login()`
- **Routes**: `saveRoute()`, `getUserRoutes()`, `createRoute()`
- **Transport**: `createTransportMode()`
- **Locations**: `createLocation()`
- **Travel**: `createTravelLog()`
- **Safety**: `createSafetyReport()`, `createIncident()`

```dart
// Example: Save journey to backend
await BackendService.saveRoute(
  userId: 1,
  route: recordedRoute,
);

// Create travel log automatically
await BackendService.createTravelLog(
  userId: 1,
  recordedRouteId: 'route-uuid',
  transportModeId: 1,
  startedAt: DateTime.now().subtract(Duration(minutes: 20)),
  endedAt: DateTime.now(),
  distanceMeters: 5000,
  durationSeconds: 1200,
  notes: 'Safe and reliable bus service',
);
```

#### **RoutePathPlannerService** - Smart Routing
- **Multi-modal routing**: Detects transport mode → calculates optimal path
- **Bus stop detection**: Finds nearest stops using Nominatim
- **Path composition**: Creates 3-segment routes for buses
- **Fallback logic**: If bus stops unavailable, uses driving route

```dart
// Example: Calculate multi-modal path
final segments = await RoutePathPlannerService.calculatePath(
  LatLng(-1.2921, 36.8219),  // Start
  LatLng(-1.2865, 36.8245),  // End
  'Bus',                       // Transport mode
);

// Returns:
// [
//   PathSegment(walking: 0.5km),
//   PathSegment(bus: 5.0km),
//   PathSegment(walking: 0.25km),
// ]
```

#### **AuthService** - Authentication Management
- **Backend integration**: Registers/logs in via BackendService
- **Session storage**: Stores auth token locally
- **Session retrieval**: Gets stored session on app launch

```dart
// Register with backend
final session = await AuthService.instance.registerWithEmail(
  name: 'Jane Doe',
  email: 'jane@example.com',
  phone: '+254712345678',
  password: 'SecurePassword123',
);

// userId from session used for all data saves
final userId = session.user.id;
```

## Screen Integration Details

### **MapPickerScreen**
- **Input**: Origin and destination locations
- **Transport Mode Selection**: Shows 7 modes (Walking, Bicycle, Motorcycle, Car, Bus, Taxi, Tricycle)
- **Route Calculation**: Calls `RoutePathPlannerService.calculatePath()`
- **Path Visualization**: Displays multi-segment paths with color coding
- **Output**: Routes to RouteRecorderScreen with selected mode

**Key Code**:
```dart
void _selectTransportMode(String mode) {
  setState(() {
    _selectedTransportMode = mode;
  });
  
  // Calculate path when mode is selected
  if (_start != null && _destination != null) {
    _fetchRoute(_start!, _destination!, mode);
  }
}
```

### **RouteRecorderScreen**
- **Starts location tracking** from map selection
- **Collects GPS coordinates** as user travels
- **Detects arrival** at destination
- **Prompts for rating** (1-5 stars for safety)
- **Collects notes** (safety observations)
- **Saves everything** to backend

**Data Saved**:
1. **recorded_routes**: Full GPS trace
2. **travel_logs**: Journey metadata
3. **transport_modes**: Mode classification
4. **safety_reports**: If safety concerns mentioned

**Key Code**:
```dart
Future<void> _saveRoute() async {
  // Stop recording and get final route
  final route = await _recorderService.stopRecording(...);
  
  // Save to backend if authenticated
  if (widget.userId != null) {
    await BackendService.saveRoute(
      userId: widget.userId!,
      route: route,
    );
    
    // Also create travel log
    await BackendService.createTravelLog(
      userId: widget.userId!,
      recordedRouteId: route.id,
      transportModeId: transportModeId,
      startedAt: route.startTime,
      endedAt: route.endTime,
      distanceMeters: route.distance,
      durationSeconds: route.duration.inSeconds,
      notes: userNotes,
    );
    
    // Create safety report if concerns noted
    if (userNotes.contains('unsafe')) {
      await BackendService.createSafetyReport(
        userId: widget.userId!,
        description: userNotes,
        severity: 5 - rating,
      );
    }
  }
}
```

### **AuthScreen**
- **Register**: Collects name, email, phone, password
- **Login**: Validates credentials with backend
- **Stores session**: Saves auth token locally
- **Auto-login**: Loads stored session on app startup

## Database Tables Updated

### **users** ← Updated by AuthService
- User registration and login data

### **recorded_routes** ← Updated by RouteRecorderScreen
- GPS traces with timestamps
- Transport mode selection
- Safety ratings (1-5)
- User notes
- Distance and duration

### **travel_logs** ← Auto-created after route recording
- Reference to recorded_route
- Transport mode ID
- Start/end times
- Distance and duration
- User notes

### **transport_modes** ← Auto-created as needed
- Pre-defined or user-provided modes

### **safety_reports** ← Auto-created if concerns noted
- Description of safety issues
- Severity rating
- Location reference

### **incidents** ← Can be created from safety reports
- Specific incident type
- Detailed description
- Location and time

## Configuration

### Backend URL
Set in `lib/services/backend_service.dart`:
```dart
static const String _baseUrl = 'http://localhost:3000'; // Change for production
```

For production:
```dart
static const String _baseUrl = 'https://api.saferoute.app';
```

### External Services
- **OSRM**: `http://router.project-osrm.org` (Routing)
- **Nominatim**: `https://nominatim.openstreetmap.org` (Geocoding & Bus stops)
- **OpenStreetMap**: Tile layer for maps

## API Communication Flow

### Example: Complete Journey Workflow

```
1. User opens app → AuthService checks stored session
   ↓
2. User navigates to MapPickerScreen
   ↓
3. User selects "Bus" transport mode
   ↓
4. RoutePathPlannerService.calculatePath() is called
   ↓
   a) Finds nearest bus stop via Nominatim
   b) Calculates walk→bus→walk segments via OSRM
   ↓
5. Route is displayed with color coding
   ↓
6. User confirms and starts journey (RouteRecorderScreen)
   ↓
7. GPS coordinates collected in real-time
   ↓
8. User arrives at destination
   ↓
9. Rating dialog appears (1-5 stars)
   ↓
10. Notes dialog (safety observations)
    ↓
11. Save button pressed
    ↓
12. BackendService.saveRoute() → POST /routes/record
    ↓
13. BackendService.createTransportMode() → POST /transport-modes
    ↓
14. BackendService.createTravelLog() → POST /travel_logs
    ↓
15. If safety concerns: BackendService.createSafetyReport() → POST /safety_reports
    ↓
16. Data stored in PostgreSQL
    ↓
17. Success message to user
```

### Network Requests Made

```
Geocoding (Nominatim):
GET https://nominatim.openstreetmap.org/search
  ?q=location_name&format=json

Routing (OSRM):
GET http://router.project-osrm.org/route/v1/{profile}/{lon1},{lat1};{lon2},{lat2}
  ?overview=full&geometries=geojson

Bus Stop Detection (Nominatim):
GET https://nominatim.openstreetmap.org/search
  ?format=json&q=amenity=bus_stop&lat={lat}&lon={lon}&radius=500

Backend APIs:
POST /auth/register
POST /auth/login
POST /routes/record
POST /travel_logs
POST /safety_reports
POST /transport-modes
POST /locations
```

## Error Handling

### Connection Errors
- Backend unavailable → Routes still calculate (offline routing)
- API calls fail → User notified with snackbar
- Data saved locally (SharedPreferences) → Retry on reconnect

### Validation Errors
- Route < 100m → Rejected
- Journey < 30 seconds → Rejected
- Missing required fields → Form validation prevents submission

### Safety Report Auto-Detection
```dart
// Triggered if:
- userNotes.contains('unsafe') 
- userNotes.contains('danger')
- userNotes.contains('problem')
- rating <= 2 (low safety rating)

// Creates safety_report with severity = 5 - rating
```

## Testing

### Test Route with Specific Mode

```dart
// Test walking route
final walkSegments = await RoutePathPlannerService.calculatePath(
  LatLng(-1.2921, 36.8219),
  LatLng(-1.2865, 36.8245),
  'Walking',
);
expect(walkSegments?.length, 1);
expect(walkSegments?[0].transportMode, 'walking');

// Test bus route (3 segments)
final busSegments = await RoutePathPlannerService.calculatePath(
  LatLng(-1.2921, 36.8219),
  LatLng(-1.2865, 36.8245),
  'Bus',
);
expect(busSegments?.length, 3);
expect(busSegments?[0].transportMode, 'walking');
expect(busSegments?[1].transportMode, 'bus');
expect(busSegments?[2].transportMode, 'walking');
```

### Test Backend Integration

```bash
# Test registration
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","password":"Test1234"}'

# Test saving route
curl -X POST http://localhost:3000/routes/record \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "startLocationName": "Home",
    "endLocationName": "Work",
    "transportMode": "Bus",
    "startLatitude": -1.2921,
    "startLongitude": 36.8219,
    "endLatitude": -1.2865,
    "endLongitude": 36.8245,
    "coordinates": [{"lat": -1.2921, "lng": 36.8219}],
    "distance": 5000,
    "duration": 1200,
    "rating": 4,
    "notes": "Safe",
    "startedAt": "2026-05-13T08:00:00Z",
    "endedAt": "2026-05-13T08:20:00Z"
  }'
```

## Deployment Checklist

- [ ] Update `_baseUrl` in BackendService to production API
- [ ] Ensure PostgreSQL is running with correct credentials
- [ ] Run backend server: `dart run bin/server.dart`
- [ ] Initialize database schema: `psql -f schema.sql`
- [ ] Test registration/login flow
- [ ] Test route recording and saving
- [ ] Verify multi-modal path planning for buses
- [ ] Monitor backend logs for errors
- [ ] Test offline mode (local caching)
- [ ] Deploy to app stores

## Summary

The SafeRoute app now:
✅ **Authenticates** users via PostgreSQL backend
✅ **Records routes** with GPS tracking
✅ **Calculates intelligent paths** including bus routes with walking segments
✅ **Automatically creates** travel logs and safety reports
✅ **Stores all data** in PostgreSQL for analysis
✅ **Detects safety concerns** and creates incident reports
✅ **Supports multi-modal transport** with visual differentiation

All user journeys are permanently logged for transport poverty mapping and safe route analysis.
