# SafeRoute

SafeRoute is a Flutter app for mapping transport poverty and recommending safer routes for women commuters.

## Features

- Transport-poverty snapshot cards with high-risk stop and corridor signals.
- Safe-route recommendations filtered by commute period.
- Community safety actions for reporting unsafe stops, sharing trips, and saving contacts.
- Registration and login forms backed by a PostgreSQL user store through a Django backend API.
- Route recording with GPS tracking from a user-defined origin to destination.
- Named location storage: users can enter origin and destination location names, which are geocoded and persisted alongside route coordinates.
- Route ratings and safety notes: users can rate routes (1-5 stars) and add safety observations that are stored in the database.

## Run

```bash
flutter pub get
flutter run
```

To connect the app to the backend API, ensure the backend server is running on `http://localhost:3000`.

If you are running on a physical Android phone, start the backend on all interfaces. The app has `192.168.1.20` baked in as the local Wi-Fi fallback, so it can keep working after USB is unplugged:

```bash
cd backend
python manage.py runserver 0.0.0.0:3000

flutter run --dart-define=SAFE_ROUTE_SERVER_HOST=192.168.1.20
```

Use your computer's real IP address on the same Wi-Fi network. If the IP changes, run with `--dart-define=SAFE_ROUTE_SERVER_HOST=<new-ip>` or set the in-app Backend URL to `http://<new-ip>:3000`.

For mobile data or a server in another location, deploy the backend to a public HTTPS URL and run/build the app with:

```bash
flutter run --dart-define=SAFE_ROUTE_API_BASE_URL=https://api.yourdomain.com
```

See [backend/PRODUCTION.md](backend/PRODUCTION.md).

For Render deployment, see [backend/RENDER.md](backend/RENDER.md).

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
