# SafeRoute Django API Setup

## Architecture

```text
Flutter app
  -> Django backend in backend/
  -> PostgreSQL database
```

The Django backend preserves the original API paths used by `lib/services/backend_service.dart`.

## Database Setup

```sql
CREATE USER saferoute_user WITH PASSWORD 'your_secure_password';
CREATE DATABASE saferoute OWNER saferoute_user;
GRANT ALL PRIVILEGES ON DATABASE saferoute TO saferoute_user;
```

Optional manual schema initialization:

```bash
cd backend
psql -U saferoute_user -d saferoute -f schema.sql
```

The API also creates missing tables automatically.

## Backend Setup

```bash
cd backend
python -m pip install -r requirements.txt
```

PowerShell:

```powershell
$env:DB_HOST='localhost'
$env:DB_PORT='5432'
$env:DB_NAME='saferoute'
$env:DB_USER='saferoute_user'
$env:DB_PASSWORD='your_secure_password'
python manage.py runserver 0.0.0.0:3000
```

Linux/macOS:

```bash
export DB_HOST='localhost'
export DB_PORT='5432'
export DB_NAME='saferoute'
export DB_USER='saferoute_user'
export DB_PASSWORD='your_secure_password'
python manage.py runserver 0.0.0.0:3000
```

## Endpoints

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `POST /routes/record`
- `GET /routes/user/<userId>`
- `POST /transport-modes`
- `POST /locations`
- `POST /routes`
- `POST /travel_logs`
- `POST /safety_reports`
- `POST /incidents`

## Test

```bash
curl http://localhost:3000/health

curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123"}'
```

## Flutter Connection

The Flutter app defaults to `http://localhost:3000` on desktop/web. On Android it tries the configured LAN server and then `http://10.0.2.2:3000` for emulators. For a physical Android device, either keep this running:

```bash
adb reverse tcp:3000 tcp:3000
```

or start Flutter with your computer's LAN IP:

```bash
flutter run --dart-define=SAFE_ROUTE_SERVER_HOST=192.168.1.20
```

USB is not required for backend access when the phone and PC are on the same Wi-Fi and Windows Firewall allows port `3000`.

For mobile data or a server in another network/location, use a public HTTPS API URL:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://api.yourdomain.com
```

See `backend/PRODUCTION.md`.

## Admin Dashboard

Start Django, then open:

```text
http://localhost:3000/dashboard
```

Default local login:

```text
admin / admin123
```

For a real deployment, set:

```powershell
$env:DASHBOARD_USERNAME='admin'
$env:DASHBOARD_PASSWORD='your-secure-password'
```

Admins can manage users, inspect recorded routes, and view travel analytics.
