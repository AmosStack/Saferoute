# SafeRoute Quick Start Guide

Get the complete SafeRoute system running in 15 minutes.

## Prerequisites

- PostgreSQL 12+ installed
- Dart 3.10+ SDK installed
- Flutter 3.10+ SDK installed
- Git

## 1. Setup PostgreSQL Database (5 minutes)

### Windows PowerShell
```powershell
# Start PostgreSQL service
# (Usually runs automatically after installation)

# Create database
psql -U postgres

# In PostgreSQL shell:
CREATE USER saferoute_user WITH PASSWORD 'saferoute123';
CREATE DATABASE saferoute OWNER saferoute_user;
GRANT ALL PRIVILEGES ON DATABASE saferoute TO saferoute_user;
\q
```

### Linux/macOS
```bash
# Start PostgreSQL
sudo systemctl start postgresql  # Linux
brew services start postgresql   # macOS

# Create database
psql -U postgres

# In PostgreSQL shell:
CREATE USER saferoute_user WITH PASSWORD 'saferoute123';
CREATE DATABASE saferoute OWNER saferoute_user;
GRANT ALL PRIVILEGES ON DATABASE saferoute TO saferoute_user;
\q
```

### Initialize Schema
```bash
cd backend
psql -U saferoute_user -d saferoute -f schema.sql
```

## 2. Run Backend Server (3 minutes)

### Windows PowerShell
```powershell
cd backend

# Set environment variables
$env:DB_HOST='localhost'
$env:DB_PORT='5432'
$env:DB_NAME='saferoute'
$env:DB_USER='saferoute_user'
$env:DB_PASSWORD='saferoute123'
$env:PORT='3000'

# Install and run
dart pub get
dart run bin/server.dart
```

### Linux/macOS
```bash
cd backend

# Set environment variables
export DB_HOST='localhost'
export DB_PORT='5432'
export DB_NAME='saferoute'
export DB_USER='saferoute_user'
export DB_PASSWORD='saferoute123'
export PORT='3000'

# Install and run
dart pub get
dart run bin/server.dart
```

**Expected output:**
```
SafeRoute API running on http://0.0.0.0:3000
```

✅ Backend server is ready!

## 3. Run Flutter App (5 minutes)

### Setup (first time only)
```bash
cd SafeRoute
flutter pub get
```

### Run on Device/Emulator
```bash
# List available devices
flutter devices

# Run on default device
flutter run

# Or specify device
flutter run -d <device-id>
```

**Expected result:** App opens with login screen

## 4. Quick Test

### Test Registration
1. In app: Tap "Don't have an account? Register"
2. Fill in:
   - Name: `Test User`
   - Email: `test@example.com`
   - Phone: `+254712345678`
   - Password: `Test@123`
3. Tap "Register"
4. Verify success message

### Test Route Recording
1. App shows home screen
2. Tap "Pick Start and Destination"
3. Select origin location: "Current Location"
4. Select destination: Enter any location name
5. Choose transport mode: "Bus"
6. Observe: Multi-segment path with color coding
   - 🟢 Green = Walking to bus stop
   - 🟣 Purple = Bus route
   - 🟢 Green = Walking from bus stop
7. Tap "Start"
8. Simulate walking (tap on map or wait)
9. App notifies when arriving
10. Rate route 1-5 ⭐
11. Add notes (optional)
12. Tap "Save & Finish"
13. Verify success notification

### Test API Directly
```bash
# Check server health
curl http://localhost:3000/health

# Register user
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jane Doe",
    "email": "jane@example.com",
    "password": "Jane@1234"
  }'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "jane@example.com",
    "password": "Jane@1234"
  }'

# Create transport mode
curl -X POST http://localhost:3000/transport-modes \
  -H "Content-Type: application/json" \
  -d '{"name": "Bus"}'
```

## Database Verification

### Check Registered Users
```bash
psql -U saferoute_user -d saferoute

# In PostgreSQL:
SELECT id, name, email, created_at FROM saferoute.users;
```

### Check Recorded Routes
```bash
SELECT id, user_id, transport_mode, distance_meters, created_at 
FROM saferoute.recorded_routes;
```

### Check Travel Logs
```bash
SELECT id, user_id, transport_mode_id, distance_meters, created_at 
FROM saferoute.travel_logs;
```

### Check Safety Reports
```bash
SELECT id, user_id, description, severity, created_at 
FROM saferoute.safety_reports;

\q
```

## Troubleshooting

### Backend Won't Start
```bash
# Check PostgreSQL is running
# Windows:
Get-Service | findstr postgres

# Linux:
sudo systemctl status postgresql

# macOS:
brew services list | grep postgres

# If not running:
sudo systemctl start postgresql  # Linux
brew services start postgresql   # macOS
```

### Database Connection Error
```bash
# Verify credentials
psql -U saferoute_user -d saferoute

# If denied, reset password:
psql -U postgres
ALTER USER saferoute_user WITH PASSWORD 'saferoute123';
\q
```

### App Can't Connect to Backend
- Check backend is running: `curl http://localhost:3000/health`
- Verify backend URL in `lib/services/backend_service.dart`
- On mobile devices: Use your computer's IP instead of `localhost`
  ```dart
  static const String _baseUrl = 'http://192.168.x.x:3000';
  ```

### Port 3000 Already in Use
```bash
# Change PORT in environment:
export PORT='3001'  # Use different port

# Update BackendService:
static const String _baseUrl = 'http://localhost:3001';
```

## Understanding the Data Flow

```
1. User Register/Login
   ↓
2. Map Selection (Origin, Destination)
   ↓
3. Transport Mode Selection
   ↓
4. RoutePathPlannerService calculates path
   - If Bus: finds bus stops, creates 3-segment route
   - Otherwise: single segment route
   ↓
5. User starts journey (RouteRecorderScreen)
   - GPS tracking begins
   - Coordinates collected every ~5-10 seconds
   ↓
6. User reaches destination
   - App notifies arrival
   ↓
7. Rate and comment
   - Rating: 1-5 stars
   - Notes: safety observations
   ↓
8. Save journey
   - recorded_routes: GPS trace
   - travel_logs: journey summary
   - transport_modes: mode type
   - safety_reports: if concerns noted
   ↓
9. Data stored in PostgreSQL
```

## Key Features

### ✅ Multi-Modal Transport
- Walking, Bicycle, Car, Bus, Taxi, Motorcycle, Tricycle
- Bus mode automatically finds walking segments to nearest stops

### ✅ Safety Tracking
- Rate journey safety (1-5 stars)
- Add safety notes
- Auto-creates safety reports for low ratings or keywords

### ✅ Travel Analytics
- Distance and time tracking
- Transport mode statistics
- Safety incident mapping

### ✅ Database Integration
- All data persisted in PostgreSQL
- Real-time data capture
- Historical analysis support

## Files Structure

```
SafeRoute/
├── backend/
│   ├── bin/server.dart          # API server
│   ├── schema.sql               # Database schema
│   ├── SETUP.md                 # Detailed setup
│   └── pubspec.yaml            # Dart dependencies
├── lib/
│   ├── services/
│   │   ├── backend_service.dart           # API calls
│   │   ├── route_path_planner_service.dart # Multi-modal routing
│   │   ├── auth_service.dart              # Authentication
│   │   └── route_recorder_service.dart    # GPS tracking
│   ├── screens/
│   │   ├── map_picker_screen.dart      # Route selection
│   │   ├── route_recorder_screen.dart  # Journey recording
│   │   └── auth_screen.dart            # Login/Register
│   ├── models/
│   │   └── recorded_route.dart
│   └── main.dart
├── APP_INTEGRATION.md            # Integration details
└── pubspec.yaml                  # Flutter dependencies
```

## What's Stored in PostgreSQL

| Table | Purpose | Example |
|-------|---------|---------|
| users | Authentication | Email, password hash |
| recorded_routes | GPS traces | Full journey path |
| travel_logs | Journey summary | Distance, mode, time |
| transport_modes | Transport types | Bus, walking, bike |
| locations | Named places | Bus stops, landmarks |
| routes | Saved routes | "Morning Commute" |
| safety_reports | Safety concerns | "Poor lighting" |
| incidents | Incident details | "Assault on Main St" |

## Next Steps

1. ✅ Get it running locally
2. Explore the database with `psql`
3. Test with multiple routes
4. Try different transport modes
5. Check safety reports in database
6. Deploy to production (see SETUP.md)

## Support Resources

- **Backend Setup**: See `backend/SETUP.md`
- **App Integration**: See `APP_INTEGRATION.md`
- **API Docs**: See `backend/SETUP.md` → API Endpoints
- **Database Schema**: See `backend/schema.sql`

## Production Deployment

When ready to deploy:

1. Update `_baseUrl` in `lib/services/backend_service.dart`
2. Set up PostgreSQL on production server
3. Run backend with environment variables
4. Build Flutter app for iOS/Android
5. Submit to app stores

See `backend/SETUP.md` for production deployment details.

---

**You now have a fully functional SafeRoute system with:**
- ✅ PostgreSQL database
- ✅ Dart/Shelf backend API
- ✅ Flutter mobile app
- ✅ Multi-modal transport routing
- ✅ Safety reporting
- ✅ GPS tracking

🎉 Happy mapping!
