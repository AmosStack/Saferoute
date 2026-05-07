# SafeRoute

SafeRoute is a Flutter app for mapping transport poverty and recommending safer routes for women commuters.

## Features

- Transport-poverty snapshot cards with high-risk stop and corridor signals.
- Safe-route recommendations filtered by commute period.
- Community safety actions for reporting unsafe stops, sharing trips, and saving contacts.
- Registration and login forms backed by a MySQL user store through a small Dart API.

## Run

```bash
flutter pub get
flutter run
```

To connect the app to the auth API, set `SAFE_ROUTE_API_BASE_URL` to your backend URL when launching Flutter.

## Backend

The MySQL-backed auth server lives in [backend/README.md](backend/README.md).

## Notes

- The current build uses mock data and an illustrated map preview instead of a live mapping backend.
- Replace the placeholder emergency contacts and route data with local production sources before release.
- Replace the default API base URL when running on a physical device or a different host.
