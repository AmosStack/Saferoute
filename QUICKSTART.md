# SafeRoute Quick Start

Get the Flutter app, Django API, and PostgreSQL database running locally.

## Prerequisites

- PostgreSQL 12+
- Python 3.11+
- Flutter 3.10+
- Git

## 1. Create the Database

```sql
CREATE USER saferoute_user WITH PASSWORD 'saferoute123';
CREATE DATABASE saferoute OWNER saferoute_user;
GRANT ALL PRIVILEGES ON DATABASE saferoute TO saferoute_user;
```

Optional manual schema setup:

```bash
cd backend
psql -U saferoute_user -d saferoute -f schema.sql
```

The Django API also creates missing tables automatically when database-backed endpoints run.

## 2. Run the Django Backend

PowerShell:

```powershell
cd backend
$env:DB_HOST='localhost'
$env:DB_PORT='5432'
$env:DB_NAME='saferoute'
$env:DB_USER='saferoute_user'
$env:DB_PASSWORD='saferoute123'
python -m pip install -r requirements.txt
python manage.py runserver 0.0.0.0:3000
```

Linux/macOS:

```bash
cd backend
export DB_HOST='localhost'
export DB_PORT='5432'
export DB_NAME='saferoute'
export DB_USER='saferoute_user'
export DB_PASSWORD='saferoute123'
python -m pip install -r requirements.txt
python manage.py runserver 0.0.0.0:3000
```

Expected health check:

```bash
curl http://localhost:3000/health
```

## 3. Run the Flutter App

```bash
flutter pub get
flutter run
```

The app defaults to `http://localhost:3000` on desktop/web. On Android emulator it uses `http://10.0.2.2:3000`.

For a physical Android device, keep this active while USB-connected:

```bash
adb reverse tcp:3000 tcp:3000
```

For direct phone-to-server connection, run with your computer's LAN IP. The current local fallback is already `192.168.1.20`, so the app can keep talking to Django after USB is disconnected as long as the phone is on the same Wi-Fi:

```bash
flutter run --dart-define=SAFE_ROUTE_SERVER_HOST=192.168.1.20
```

If your PC IP changes, pass the new IP with `SAFE_ROUTE_SERVER_HOST` or set the in-app Backend URL to `http://<new-ip>:3000`.

For mobile data or a backend in another network/location, local IP addresses will not work. Use a public API URL:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://api.yourdomain.com
```

Production setup details are in `backend/PRODUCTION.md`.

Render setup details are in `backend/RENDER.md`.

## Quick API Test

```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com","password":"Jane1234"}'

curl -X POST http://localhost:3000/transport-modes \
  -H "Content-Type: application/json" \
  -d '{"name":"Bus"}'
```

## Admin Dashboard

Open:

```text
http://localhost:3000/dashboard
```

Default local credentials are `admin` / `admin123`. Change them with `DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD` before deployment.

## Main Files

```text
SafeRoute/
  backend/
    manage.py
    api/
    saferoute_api/
    schema.sql
    requirements.txt
  lib/
    services/backend_service.dart
    services/auth_service.dart
    services/route_path_planner_service.dart
    services/route_recorder_service.dart
```

You now have:

- PostgreSQL database
- Django backend API
- Flutter mobile app
- Route recording
- Safety reporting
- GPS tracking
