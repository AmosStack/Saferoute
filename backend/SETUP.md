# SafeRoute Database & API Setup Guide

This guide explains how to set up and use the PostgreSQL database for SafeRoute, including the backend API and mobile app integration.

## Architecture Overview

```
Flutter Mobile App (lib/)
    ↓ (HTTP requests)
Dart Backend API (backend/bin/server.dart)
    ↓ (Queries)
PostgreSQL Database
    ├── users (authentication)
    ├── recorded_routes (GPS tracking data)
    ├── transport_modes (bus, walking, etc.)
    ├── locations (named places)
    ├── routes (saved route metadata)
    ├── travel_logs (journey history)
    ├── safety_reports (safety concerns)
    └── incidents (incident tracking)
```

## Database Setup

### 1. Install PostgreSQL

On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

On macOS (using Homebrew):
```bash
brew install postgresql
brew services start postgresql
```

On Windows:
Download and install from https://www.postgresql.org/download/windows/

### 2. Create Database and User

```bash
# Connect to PostgreSQL
psql -U postgres

# In psql shell:
CREATE USER saferoute_user WITH PASSWORD 'your_secure_password';
CREATE DATABASE saferoute OWNER saferoute_user;
GRANT ALL PRIVILEGES ON DATABASE saferoute TO saferoute_user;
\q
```

### 3. Initialize Schema

From the `backend/` directory:

```bash
# Connect and run schema
psql -U saferoute_user -d saferoute -f schema.sql
```

Or run the schema through the backend API (it auto-creates tables on startup).

## Backend Server Setup

### 1. Install Dependencies

```bash
cd backend
dart pub get
```

### 2. Configure Environment Variables

Create a `.env` file or set environment variables:

**On Linux/macOS:**
```bash
export DB_HOST='localhost'
export DB_PORT='5432'
export DB_NAME='saferoute'
export DB_USER='saferoute_user'
export DB_PASSWORD='your_secure_password'
export PORT='3000'
```

**On Windows PowerShell:**
```powershell
$env:DB_HOST='localhost'
$env:DB_PORT='5432'
$env:DB_NAME='saferoute'
$env:DB_USER='saferoute_user'
$env:DB_PASSWORD='your_secure_password'
$env:PORT='3000'
```

### 3. Run the Backend Server

```bash
cd backend
dart run bin/server.dart
```

Expected output:
```
SafeRoute API running on http://0.0.0.0:3000
```

## Database Tables

### users
Stores user authentication and profile information.

```sql
CREATE TABLE saferoute.users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### recorded_routes
Stores GPS traces of completed journeys with transport mode, ratings, and safety notes.

```sql
CREATE TABLE saferoute.recorded_routes (
  id UUID PRIMARY KEY,
  user_id INT NOT NULL REFERENCES saferoute.users(id),
  start_location_name TEXT,
  end_location_name TEXT,
  transport_mode TEXT NOT NULL,
  start_latitude DECIMAL(10, 8),
  start_longitude DECIMAL(11, 8),
  end_latitude DECIMAL(10, 8),
  end_longitude DECIMAL(11, 8),
  coordinates JSONB NOT NULL,  -- Array of {lat, lng} points
  distance_meters DOUBLE PRECISION,
  duration_seconds INT,
  rating INT,  -- 1-5 stars
  notes TEXT,
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### transport_modes
Pre-defined transport modes (walking, bus, bicycle, etc.).

```sql
CREATE TABLE saferoute.transport_modes (
  id SERIAL PRIMARY KEY,
  name VARCHAR(80) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### locations
Named geographic locations (bus stops, landmarks, etc.).

```sql
CREATE TABLE saferoute.locations (
  id SERIAL PRIMARY KEY,
  name TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### routes
Named routes saved by users (e.g., "Morning Commute to Office").

```sql
CREATE TABLE saferoute.routes (
  id UUID PRIMARY KEY,
  user_id INT NOT NULL REFERENCES saferoute.users(id),
  name TEXT,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### travel_logs
Journey history with transport mode and metrics.

```sql
CREATE TABLE saferoute.travel_logs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES saferoute.users(id),
  route_id UUID REFERENCES saferoute.routes(id),
  recorded_route_id UUID REFERENCES saferoute.recorded_routes(id),
  transport_mode_id INT REFERENCES saferoute.transport_modes(id),
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  distance_meters DOUBLE PRECISION,
  duration_seconds INT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### safety_reports
User-reported safety concerns on routes.

```sql
CREATE TABLE saferoute.safety_reports (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES saferoute.users(id),
  route_id UUID REFERENCES saferoute.routes(id),
  location_id INT REFERENCES saferoute.locations(id),
  description TEXT,
  severity INT,  -- 1-5 scale
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### incidents
Specific incidents associated with safety reports.

```sql
CREATE TABLE saferoute.incidents (
  id SERIAL PRIMARY KEY,
  safety_report_id INT REFERENCES saferoute.safety_reports(id),
  incident_type TEXT,  -- "assault", "theft", "poor_lighting", etc.
  description TEXT,
  location_id INT REFERENCES saferoute.locations(id),
  occurred_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### Authentication

#### Register User
```http
POST /auth/register
Content-Type: application/json

{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "password": "securePassword123"
}
```

Response:
```json
{
  "token": "uuid-token",
  "user": {
    "id": 1,
    "name": "Jane Doe",
    "email": "jane@example.com"
  }
}
```

#### Login User
```http
POST /auth/login
Content-Type: application/json

{
  "email": "jane@example.com",
  "password": "securePassword123"
}
```

### Routes

#### Record Route (with GPS trace)
```http
POST /routes/record
Content-Type: application/json

{
  "userId": 1,
  "startLocationName": "Home",
  "endLocationName": "Office",
  "transportMode": "Bus",
  "startLatitude": -1.2921,
  "startLongitude": 36.8219,
  "endLatitude": -1.2865,
  "endLongitude": 36.8245,
  "coordinates": [
    {"lat": -1.2921, "lng": 36.8219},
    {"lat": -1.2920, "lng": 36.8220},
    ...
  ],
  "distance": 2500.5,
  "duration": 1200,
  "rating": 4,
  "notes": "Safe route, good lighting",
  "startedAt": "2026-05-13T08:00:00Z",
  "endedAt": "2026-05-13T08:20:00Z"
}
```

#### Get User Routes
```http
GET /routes/user/1
```

Response:
```json
{
  "routes": [
    {
      "id": "uuid-1",
      "startLocationName": "Home",
      "endLocationName": "Office",
      "transportMode": "Bus",
      "distance": 2500.5,
      "duration": 1200,
      "rating": 4,
      "notes": "Safe route, good lighting",
      "startedAt": "2026-05-13T08:00:00Z",
      "endedAt": "2026-05-13T08:20:00Z",
      "createdAt": "2026-05-13T08:25:00Z"
    }
  ]
}
```

### Transport Modes

#### Create Transport Mode
```http
POST /transport-modes
Content-Type: application/json

{
  "name": "Bus"
}
```

Response:
```json
{
  "id": 1,
  "name": "Bus"
}
```

### Locations

#### Create Location
```http
POST /locations
Content-Type: application/json

{
  "name": "Main Bus Station",
  "latitude": -1.2865,
  "longitude": 36.8245
}
```

Response:
```json
{
  "id": 1
}
```

### Travel Logs

#### Create Travel Log
```http
POST /travel_logs
Content-Type: application/json

{
  "userId": 1,
  "recordedRouteId": "uuid-route",
  "transportModeId": 2,
  "startedAt": "2026-05-13T08:00:00Z",
  "endedAt": "2026-05-13T08:20:00Z",
  "distance": 2500.5,
  "duration": 1200,
  "notes": "Crowded but safe"
}
```

Response:
```json
{
  "id": 123
}
```

### Safety Reports

#### Create Safety Report
```http
POST /safety_reports
Content-Type: application/json

{
  "userId": 1,
  "recordedRouteId": "uuid-route",
  "locationId": 5,
  "description": "Poor street lighting near roundabout",
  "severity": 3
}
```

Response:
```json
{
  "id": 45
}
```

### Incidents

#### Create Incident
```http
POST /incidents
Content-Type: application/json

{
  "safetyReportId": 45,
  "incidentType": "poor_lighting",
  "description": "No street lights on junction",
  "locationId": 5,
  "occurredAt": "2026-05-13T20:30:00Z"
}
```

Response:
```json
{
  "id": 789
}
```

## Multi-Modal Transport Path Planning (Bus Support)

When a user selects **Bus** as transport mode, the app automatically:

1. **Finds nearest bus stop** to the starting location (500m radius)
2. **Calculates walking route** from start → nearest bus stop
3. **Calculates bus route** using driving profile (bus stop → bus stop)
4. **Calculates walking route** from destination bus stop → final destination
5. **Displays composite route** with color-coded segments:
   - 🟢 **Green**: Walking segments
   - 🟣 **Purple**: Bus segments
   - 🟠 **Orange**: Bicycle segments
   - 🔵 **Blue**: Driving segments

### Example Response

```dart
List<PathSegment> segments = [
  PathSegment(
    transportMode: 'walking',
    points: [LatLng(-1.2921, 36.8219), ...],
    distance: 500.0,
    duration: 300,  // 5 minutes
  ),
  PathSegment(
    transportMode: 'bus',
    points: [LatLng(-1.2865, 36.8245), ...],
    distance: 5000.0,
    duration: 900,  // 15 minutes
  ),
  PathSegment(
    transportMode: 'walking',
    points: [..., LatLng(-1.2800, 36.8300)],
    distance: 250.0,
    duration: 150,  // 2.5 minutes
  ),
];
```

## Flutter App Integration

The mobile app uses these services to connect with the backend:

### Services

- **BackendService** (`lib/services/backend_service.dart`)
  - Handles all API calls to the backend
  - Manages auth, routes, travel logs, safety reports

- **RoutePathPlannerService** (`lib/services/route_path_planner_service.dart`)
  - Calculates paths based on transport mode
  - Handles multi-modal routing (especially buses)
  - Uses OSRM for routing and Nominatim for bus stop detection

- **AuthService** (`lib/services/auth_service.dart`)
  - Manages user authentication
  - Stores sessions locally
  - Communicates with backend API

### Example Usage in Flutter

```dart
// Register user
final session = await AuthService.instance.registerWithEmail(
  name: 'Jane Doe',
  email: 'jane@example.com',
  phone: '+254712345678',
  password: 'SecurePass123',
);

// Calculate path (auto-detects bus with walking segments)
final segments = await RoutePathPlannerService.calculatePath(
  LatLng(-1.2921, 36.8219),  // Start
  LatLng(-1.2865, 36.8245),  // End
  'Bus',                       // Transport mode
);

// Save route to backend
await BackendService.saveRoute(
  userId: session.user.id,
  route: recordedRoute,
);

// Create travel log
await BackendService.createTravelLog(
  userId: session.user.id,
  recordedRouteId: 'route-id',
  transportModeId: 2,
  startedAt: DateTime.now().subtract(Duration(minutes: 20)),
  endedAt: DateTime.now(),
  distanceMeters: 5000,
  durationSeconds: 1200,
  notes: 'Safe journey, good bus service',
);
```

## Testing

### Quick API Test with cURL

```bash
# Register
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "TestPass123"
  }'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "TestPass123"
  }'

# Create transport mode
curl -X POST http://localhost:3000/transport-modes \
  -H "Content-Type: application/json" \
  -d '{"name": "Bus"}'

# Create safety report
curl -X POST http://localhost:3000/safety_reports \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "description": "Poor lighting area",
    "severity": 3
  }'
```

### View Database

```bash
psql -U saferoute_user -d saferoute

# In psql:
SELECT * FROM saferoute.users;
SELECT * FROM saferoute.recorded_routes;
SELECT * FROM saferoute.travel_logs;
SELECT * FROM saferoute.safety_reports;
\q
```

## Production Deployment

### Environment Variables (Production)

Set these in your hosting environment:

```
DB_HOST=your-production-db-host.com
DB_PORT=5432
DB_NAME=saferoute_prod
DB_USER=saferoute_prod_user
DB_PASSWORD=your-super-secure-password
PORT=3000
```

### Docker Deployment

```dockerfile
FROM google/dart:3.10

WORKDIR /app
COPY backend .

RUN dart pub get
RUN dart pub global activate shelf

EXPOSE 3000

CMD ["dart", "run", "bin/server.dart"]
```

```bash
docker build -t saferoute-api .
docker run -e DB_HOST=db.example.com -e DB_USER=saferoute_user -e DB_PASSWORD=secret -p 3000:3000 saferoute-api
```

## Troubleshooting

### Connection Refused
- Ensure PostgreSQL is running: `sudo systemctl status postgresql`
- Check database credentials in environment variables
- Verify firewall allows port 5432

### API Returns 500 Error
- Check backend logs for SQL errors
- Ensure schema is initialized: `psql -U saferoute_user -d saferoute -f schema.sql`
- Restart backend server

### No Bus Stops Found
- Nominatim (OpenStreetMap) may not have bus stops in your area
- App will fall back to driving profile
- Consider adding custom bus stop data to `locations` table

### Authentication Issues
- Verify password is at least 8 characters
- Check email format is valid
- Ensure no duplicate email accounts

## Next Steps

1. ✅ Set up PostgreSQL
2. ✅ Initialize database schema
3. ✅ Run backend server
4. ✅ Update Flutter app API URLs if needed
5. ✅ Test with sample data
6. ✅ Deploy to production

## Support

For issues, check:
- Backend logs: `dart run bin/server.dart` output
- Database: `psql -U saferoute_user -d saferoute`
- Network: `curl http://localhost:3000/health`
