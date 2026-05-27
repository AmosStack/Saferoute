# SafeRoute Public Backend Setup

Use this when the Android phone may be on mobile data and the server is in another network or location.

## What Must Be True

- The backend must be reachable from the public internet using a domain or public IP.
- HTTPS is strongly recommended for login and route data.
- PostgreSQL must be reachable by the Django server.
- The Android app must be built with the public API URL.

Private addresses like `192.168.x.x`, `10.x.x.x`, and `localhost` only work on the same local network. They will not work from mobile data.

## Backend Environment

Create production environment variables like:

```bash
DB_HOST=your-postgres-host
DB_PORT=5432
DB_NAME=saferoute
DB_USER=saferoute_user
DB_PASSWORD=your-secure-password
DJANGO_DEBUG=false
DJANGO_SECRET_KEY=your-long-random-secret
DJANGO_ALLOWED_HOSTS=api.yourdomain.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://api.yourdomain.com
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=your-secure-dashboard-password
```

## Run Command

For a Linux host or cloud service:

```bash
cd backend
python -m pip install -r requirements.txt
gunicorn saferoute_api.wsgi:application --bind 0.0.0.0:3000
```

Put Nginx, Caddy, Apache, or your cloud platform in front of Gunicorn to provide HTTPS.

For Render, use the service port variable:

```bash
gunicorn saferoute_api.wsgi:application --bind 0.0.0.0:$PORT
```

See `RENDER.md` for exact Render settings.

## App Build For Any Network

Build or run the Android app with the public URL:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://api.yourdomain.com
```

For release:

```bash
flutter build apk --release --dart-define=SAFE_ROUTE_API_BASE_URL=https://api.yourdomain.com
```

If you use a raw public IP and HTTP during testing:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=http://203.0.113.10:3000
```

HTTPS with a domain is the better production setup.

Android debug builds in this project allow HTTP for local testing, but production traffic should use HTTPS because users send login and route data.

## Health Check

From a phone on mobile data or any machine outside the server network, open:

```text
https://api.yourdomain.com/health
```

It should return:

```json
{"status":"ok"}
```
