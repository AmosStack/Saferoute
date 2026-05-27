# SafeRoute Backend

This is the Django API for SafeRoute. It keeps the same HTTP endpoints and JSON payloads that the Flutter app already uses, while storing data in PostgreSQL under the existing `saferoute` schema.

## Requirements

- Python 3.11+
- PostgreSQL 12+

## Environment Variables

- `DB_HOST` defaults to `localhost`
- `DB_PORT` defaults to `5432`
- `DB_USER` defaults to `postgres`
- `DB_PASSWORD` defaults to `postgres`
- `DB_NAME` defaults to `saferoute`
- `DJANGO_SECRET_KEY` optional for local development
- `DJANGO_DEBUG` defaults to `true`
- `DJANGO_ALLOWED_HOSTS` defaults to `*`
- `GOOGLE_OAUTH_CLIENT_ID` is used to verify Google sign-in tokens

## Run

```bash
cd backend
python -m pip install -r requirements.txt
python manage.py runserver 0.0.0.0:3000
```

The Flutter app uses the LAN fallback `http://192.168.1.20:3000` on Android and `http://10.0.2.2:3000` on Android emulator. For a physical Android phone, keep Django bound to `0.0.0.0` and run Flutter with your computer's LAN IP:

```bash
flutter run --dart-define=SAFE_ROUTE_SERVER_HOST=192.168.1.20
```

If the phone still cannot connect after USB is unplugged, confirm the phone and PC are on the same Wi-Fi and allow inbound traffic to port `3000` in Windows Firewall.

For mobile data or a server in another network/location, use a public domain or public IP instead of a LAN IP:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://api.yourdomain.com
```

See [PRODUCTION.md](PRODUCTION.md) for deployment notes.

For Render specifically, see [RENDER.md](RENDER.md). This repo includes a root-level `render.yaml` Blueprint.

## Admin Dashboard

Open the system admin dashboard at:

```text
http://localhost:3000/dashboard
```

Default local credentials:

```text
Username: admin
Password: admin123
```

Set these environment variables before starting Django to change them:

```powershell
$env:DASHBOARD_USERNAME='admin'
$env:DASHBOARD_PASSWORD='change-this-password'
```

The dashboard supports:

- User CRUD: create, edit, delete, and search users.
- Route inspection: view recorded routes, transport mode, distance, duration, ratings, notes, and coordinate samples.
- Analytics: total users, routes, distance, travel time, route volume by mode/day, safety reports, and top travelers.
- Map view: visualize recent routes and complaint hot spots on an interactive map.
- Complaint review: inspect safety reports and incident clusters tied to specific locations.

## API

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

## Database

The server creates the required schema and tables automatically when API endpoints touch the database. You can also initialize manually:

```bash
cd backend
psql -U saferoute_user -d saferoute -f schema.sql
```

The main tables are:

- `saferoute.users`
- `saferoute.recorded_routes`
- `saferoute.transport_modes`
- `saferoute.locations`
- `saferoute.routes`
- `saferoute.travel_logs`
- `saferoute.safety_reports`
- `saferoute.incidents`

## Quick Test

```bash
curl http://localhost:3000/health

curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Jane Doe\",\"email\":\"jane@example.com\",\"password\":\"Jane1234\"}"
```
