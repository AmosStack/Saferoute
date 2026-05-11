# SafeRoute Backend

This Dart API stores users and recorded routes in PostgreSQL and serves registration/login plus route recording endpoints for the Flutter app.

## Required environment variables

- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `PORT`

## Run

```bash
cd backend
dart pub get
dart run bin/server.dart
```

## API

- `POST /auth/register`
- `POST /auth/login`
- `GET /health`
- `POST /routes/record`
- `GET /routes/user/<userId>`

## Database Tables

- `saferoute.users`: authenticated app users.
- `saferoute.recorded_routes`: saved routes, including origin and destination names, transport mode, GPS coordinates, rating, notes, and timestamps.

## Notes

- The server creates the `users` and `recorded_routes` tables automatically if they do not exist.
- The Flutter app expects the API base URL in `SAFE_ROUTE_API_BASE_URL` and defaults to `http://10.0.2.2:3000`.