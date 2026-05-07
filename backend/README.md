# SafeRoute Backend

This Dart API stores users in MySQL and serves registration/login endpoints for the Flutter app.

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

## Notes

- The server creates the `users` table automatically if it does not exist.
- The Flutter app expects the API base URL in `SAFE_ROUTE_API_BASE_URL` and defaults to `http://10.0.2.2:3000`.