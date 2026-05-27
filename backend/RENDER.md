# Deploy SafeRoute Backend on Render

Render can host the Django API and admin dashboard. Your Flutter app will then work from Wi-Fi, mobile data, and other networks by using the Render HTTPS URL.

## 1. Prepare a Database

Use either:

- Render PostgreSQL, then copy its internal or external connection string.
- Supabase PostgreSQL, then copy the pooled or direct connection string.

Put that connection string in Render as `DATABASE_URL`.

## 2. Create the Render Web Service

You can use the included root-level `render.yaml`, or configure manually in Render:

```text
Root Directory: backend
Build Command: python -m pip install -r requirements.txt
Start Command: gunicorn saferoute_api.wsgi:application --bind 0.0.0.0:$PORT
Health Check Path: /health
```

Environment variables:

```text
DATABASE_URL=<your postgres connection string>
DJANGO_DEBUG=false
DJANGO_SECRET_KEY=<long random secret>
DJANGO_ALLOWED_HOSTS=<your-service-name>.onrender.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://<your-service-name>.onrender.com
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=<secure admin password>
```

If you use a custom domain, put that domain in `DJANGO_ALLOWED_HOSTS` and `DJANGO_CSRF_TRUSTED_ORIGINS`.

## 3. Verify the API

After deploy, open:

```text
https://<your-service-name>.onrender.com/health
```

Expected response:

```json
{"status":"ok"}
```

The dashboard will be:

```text
https://<your-service-name>.onrender.com/dashboard
```

## 4. Build the Flutter App for Render

Use the Render URL as the API base:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://<your-service-name>.onrender.com
```

Release build:

```bash
flutter build apk --release --dart-define=SAFE_ROUTE_API_BASE_URL=https://<your-service-name>.onrender.com
```

Once the app is built with this URL, users can use it from mobile data or any Wi-Fi network.
