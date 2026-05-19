# SafeRoute

SafeRoute is a Flutter app for mapping transport poverty and recommending safer routes for women commuters.

## Features

- Transport-poverty snapshot cards with high-risk stop and corridor signals.
- Safe-route recommendations filtered by commute period.
- Community safety actions for reporting unsafe stops, sharing trips, and saving contacts.
- Registration and login forms backed by a PostgreSQL user store through a Dart backend API.
- Route recording with GPS tracking from a user-defined origin to destination.
- Named location storage: users can enter origin and destination location names, which are geocoded and persisted alongside route coordinates.
- Route ratings and safety notes: users can rate routes (1-5 stars) and add safety observations that are stored in the database.

## Run

```bash
flutter pub get
flutter run
```

To connect the app to the backend API, ensure the backend server is running on `http://localhost:3000`.

If you are running on a physical Android phone and disconnect USB, `adb reverse` stops working. In that case, start the app with a LAN base URL, for example:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=http://192.168.1.50:3000
```

Use your computer's real IP address on the local network.

### Recording Routes

1. On the home screen, tap **"Find safe route"** to open the map picker.
2. Enter an **origin location name** (e.g., "Home", "Work address") in the origin field.
3. Enter a **destination location name** in the destination field.
4. Tap the search icon to geocode each location, or tap on the map to set coordinates manually.
5. Confirm both points are set, then tap **"Confirm"** to start recording.
6. The route recorder will track your GPS position and display distance and duration.
7. When you arrive near the destination, a confirmation dialog appears.
8. Rate the route (1-5 stars) and optionally add safety notes.
9. Tap **"Save & Finish"** to persist the route with location names to the database.

## Backend

The PostgreSQL-backed server lives in [backend/README.md](backend/README.md). It handles authentication, route recording, and retrieval with location names and GPS coordinates.

## Notes

- Routes are stored with both location names (e.g., "Home", "City Center") and precise GPS coordinates.
- Location names are geocoded using OpenStreetMap's Nominatim service to resolve them into coordinates for routing.
- The current build uses mock data for the home screen recommendations and an illustrated map preview.
- Replace the placeholder emergency contacts and route data with local production sources before release.
- Ensure the PostgreSQL database is running with the schema initialized (see [backend/README.md](backend/README.md)).
