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
DATABASE_URL=postgresql://saferoute_4jd4_user:E7N8rz32diGbqHwbb95pj6BE4KCPSmr4@dpg-d8bem7jbc2fs73c9i7h0-a/saferoute_4jd4
DJANGO_DEBUG=false
DJANGO_SECRET_KEY=3n7#4(3suxq#$b1updbu!w*7gd6)$phuw&9-i+1)^t#%^6k*t%
DJANGO_ALLOWED_HOSTS=saferoute-api-jk60.onrender.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://saferoute-api-jk60.onrender.com
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=admin123
GOOGLE_OAUTH_CLIENT_ID=105928817756-d4pbc059dccu5o7jq63b6ep9mt4shdu9.apps.googleusercontent.com


Hostname=dpg-d8u0obgg4nts73dfrgpg-a.virginia-postgres.render.com
Database=saferoute_4jd4_0eem
Database_User=saferoute_4jd4_user
Password=E7N8rz32diGbqHwbb95pj6BE4KCPSmr4

Internal Database URL=postgresql://saferoute_4jd4_user:E7N8rz32diGbqHwbb95pj6BE4KCPSmr4@dpg-d8bem7jbc2fs73c9i7h0-a/saferoute_4jd4

External Database URL=postgresql://saferoute_4jd4_user:E7N8rz32diGbqHwbb95pj6BE4KCPSmr4@dpg-d8bem7jbc2fs73c9i7h0-a.virginia-postgres.render.com/saferoute_4jd4

PSQL Command=PGPASSWORD=E7N8rz32diGbqHwbb95pj6BE4KCPSmr4 psql -h dpg-d8bem7jbc2fs73c9i7h0-a.virginia-postgres.render.com -U saferoute_4jd4_user saferoute_4jd4
```

If you use a custom domain, put that domain in `DJANGO_ALLOWED_HOSTS` and `DJANGO_CSRF_TRUSTED_ORIGINS`.

## 3. Verify the API

After deploy, open:

```text
https://saferoute-api-jk60.onrender.com/health
```

Expected response:

```json
{"status":"ok"}
```

The dashboard will be:

```text
https://saferoute-api-jk60.onrender.com/dashboard
```

Sign-in uses the browser's Basic Auth prompt, not a separate form. Use the values from `DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD` in Render. If you already tried the wrong password, open the dashboard in an incognito/private window so the browser does not reuse cached credentials.

## 4. Build the Flutter App for Render

Use the Render URL as the API base:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://saferoute-api-jk60.onrender.com
```

Release build:

```bash
flutter build apk --release --dart-define=SAFE_ROUTE_API_BASE_URL=https://saferoute-api-jk60.onrender.com
```

Once the app is built with this URL, users can use it from mobile data or any Wi-Fi network.
