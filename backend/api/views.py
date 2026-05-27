import json
import uuid
from decimal import Decimal

try:
    import bcrypt as legacy_bcrypt
except ImportError:  # pragma: no cover - optional compatibility path
    legacy_bcrypt = None

from django.contrib.auth.hashers import check_password, make_password
from django.db import connection
from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from .db import ensure_schema


def _decode_request(request: HttpRequest) -> dict:
    if not request.body:
        return {}
    return json.loads(request.body.decode("utf-8"))


def _bad_request(message: str) -> JsonResponse:
    return JsonResponse({"message": message}, status=400)


def _unauthorized(message: str) -> JsonResponse:
    return JsonResponse({"message": message}, status=401)


def _server_error(message: str) -> JsonResponse:
    return JsonResponse({"message": message}, status=500)


def _build_session(user: dict) -> dict:
    return {"token": str(uuid.uuid4()), "user": user}


def _password_matches(password: str, stored_hash: str) -> bool:
    if check_password(password, stored_hash):
        return True

    if legacy_bcrypt is None or not stored_hash.startswith("$2"):
        return False

    return legacy_bcrypt.checkpw(password.encode("utf-8"), stored_hash.encode("utf-8"))


def _to_json_value(value):
    if isinstance(value, Decimal):
        return float(value)
    return value


def _json_field(value):
    if isinstance(value, str):
        return json.loads(value)
    return value


@require_GET
def health(request: HttpRequest) -> JsonResponse:
    return JsonResponse({"status": "ok"})


@csrf_exempt
@require_POST
def register(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        name = str(payload.get("name") or "").strip()
        email = str(payload.get("email") or "").strip().lower()
        password = str(payload.get("password") or "")

        if not name or not email or len(password) < 8:
            return _bad_request("Provide a name, email, and password with at least 8 characters.")

        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM saferoute.users WHERE email = %s LIMIT 1", [email])
            if cursor.fetchone():
                return _bad_request("An account with that email already exists.")

            password_hash = make_password(password)
            cursor.execute(
                """
                INSERT INTO saferoute.users (name, email, password_hash)
                VALUES (%s, %s, %s)
                RETURNING id
                """,
                [name, email, password_hash],
            )
            user_id = cursor.fetchone()[0]

        return JsonResponse(_build_session({"id": user_id, "name": name, "email": email}))
    except Exception as exc:
        return _server_error(f"Registration failed: {exc}")


@csrf_exempt
@require_POST
def login(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        email = str(payload.get("email") or "").strip().lower()
        password = str(payload.get("password") or "")

        if not email or not password:
            return _bad_request("Email and password are required.")

        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, email, password_hash
                FROM saferoute.users
                WHERE email = %s
                LIMIT 1
                """,
                [email],
            )
            row = cursor.fetchone()

        if not row:
            return _unauthorized("Invalid email or password.")

        user_id, user_name, user_email, stored_hash = row
        if not _password_matches(password, stored_hash):
            return _unauthorized("Invalid email or password.")

        return JsonResponse(_build_session({"id": user_id, "name": user_name, "email": user_email}))
    except Exception as exc:
        return _server_error(f"Login failed: {exc}")


@csrf_exempt
@require_POST
def record_route(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        required = [
            "userId",
            "startLocationName",
            "endLocationName",
            "transportMode",
            "startLatitude",
            "startLongitude",
            "endLatitude",
            "endLongitude",
            "coordinates",
            "distance",
            "duration",
            "startedAt",
            "endedAt",
        ]
        if any(payload.get(field) in (None, "") for field in required):
            return _bad_request(
                "Missing required fields: userId, startLocationName, endLocationName, transportMode, "
                "startLatitude, startLongitude, endLatitude, endLongitude, coordinates, distance, "
                "duration, startedAt, endedAt"
            )

        route_id = str(uuid.uuid4())
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO saferoute.recorded_routes
                  (id, user_id, start_location_name, end_location_name, transport_mode,
                   start_latitude, start_longitude, end_latitude, end_longitude, coordinates,
                   distance_meters, duration_seconds, rating, notes, started_at, ended_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s, %s, %s, %s)
                """,
                [
                    route_id,
                    payload.get("userId"),
                    str(payload.get("startLocationName")).strip(),
                    str(payload.get("endLocationName")).strip(),
                    str(payload.get("transportMode")).strip(),
                    payload.get("startLatitude"),
                    payload.get("startLongitude"),
                    payload.get("endLatitude"),
                    payload.get("endLongitude"),
                    json.dumps(payload.get("coordinates")),
                    payload.get("distance"),
                    payload.get("duration"),
                    payload.get("rating"),
                    payload.get("notes"),
                    payload.get("startedAt"),
                    payload.get("endedAt"),
                ],
            )

        return JsonResponse({"id": route_id, "message": "Route recorded successfully"})
    except Exception as exc:
        return _server_error(f"Failed to record route: {exc}")


@require_GET
def get_user_routes(request: HttpRequest, user_id: int) -> JsonResponse:
    try:
        ensure_schema()
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, start_location_name, end_location_name, transport_mode,
                       start_latitude, start_longitude, end_latitude, end_longitude,
                       coordinates, distance_meters, duration_seconds, rating, notes,
                       started_at, ended_at, created_at
                FROM saferoute.recorded_routes
                WHERE user_id = %s
                ORDER BY created_at DESC
                LIMIT 100
                """,
                [user_id],
            )
            rows = cursor.fetchall()

        routes = []
        for row in rows:
            routes.append(
                {
                    "id": str(row[0]),
                    "startLocationName": row[1],
                    "endLocationName": row[2],
                    "transportMode": row[3],
                    "startLatitude": _to_json_value(row[4]),
                    "startLongitude": _to_json_value(row[5]),
                    "endLatitude": _to_json_value(row[6]),
                    "endLongitude": _to_json_value(row[7]),
                    "startPoint": {
                        "lat": _to_json_value(row[4]),
                        "lng": _to_json_value(row[5]),
                    },
                    "endPoint": {
                        "lat": _to_json_value(row[6]),
                        "lng": _to_json_value(row[7]),
                    },
                    "coordinates": _json_field(row[8]),
                    "distance": _to_json_value(row[9]),
                    "duration": row[10],
                    "rating": row[11],
                    "notes": row[12],
                    "startedAt": str(row[13]),
                    "endedAt": str(row[14]),
                    "startTime": str(row[13]),
                    "endTime": str(row[14]),
                    "createdAt": str(row[15]),
                }
            )

        return JsonResponse({"routes": routes})
    except Exception as exc:
        return _server_error(f"Failed to fetch routes: {exc}")


@csrf_exempt
@require_POST
def create_transport_mode(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        name = str(_decode_request(request).get("name") or "").strip()
        if not name:
            return _bad_request("Transport mode name required")

        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM saferoute.transport_modes WHERE name = %s LIMIT 1", [name])
            row = cursor.fetchone()
            if row:
                return JsonResponse({"id": row[0], "name": name})

            cursor.execute(
                "INSERT INTO saferoute.transport_modes (name) VALUES (%s) RETURNING id",
                [name],
            )
            transport_mode_id = cursor.fetchone()[0]

        return JsonResponse({"id": transport_mode_id, "name": name})
    except Exception as exc:
        return _server_error(f"Failed to create transport mode: {exc}")


@csrf_exempt
@require_POST
def create_location(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO saferoute.locations (name, latitude, longitude)
                VALUES (%s, %s, %s)
                RETURNING id
                """,
                [payload.get("name"), payload.get("latitude"), payload.get("longitude")],
            )
            location_id = cursor.fetchone()[0]

        return JsonResponse({"id": location_id})
    except Exception as exc:
        return _server_error(f"Failed to create location: {exc}")


@csrf_exempt
@require_POST
def create_route_meta(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        user_id = payload.get("userId")
        if user_id is None:
            return _bad_request("userId is required")

        route_id = str(uuid.uuid4())
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO saferoute.routes (id, user_id, name, description)
                VALUES (%s, %s, %s, %s)
                """,
                [route_id, user_id, str(payload.get("name") or "").strip(), payload.get("description")],
            )

        return JsonResponse({"id": route_id})
    except Exception as exc:
        return _server_error(f"Failed to create route metadata: {exc}")


@csrf_exempt
@require_POST
def create_travel_log(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        user_id = payload.get("userId")
        if user_id is None:
            return _bad_request("userId is required")

        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO saferoute.travel_logs
                  (user_id, route_id, recorded_route_id, transport_mode_id,
                   started_at, ended_at, distance_meters, duration_seconds, notes)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
                """,
                [
                    user_id,
                    payload.get("routeId"),
                    payload.get("recordedRouteId"),
                    payload.get("transportModeId"),
                    payload.get("startedAt"),
                    payload.get("endedAt"),
                    payload.get("distance"),
                    payload.get("duration"),
                    payload.get("notes"),
                ],
            )
            travel_log_id = cursor.fetchone()[0]

        return JsonResponse({"id": travel_log_id})
    except Exception as exc:
        return _server_error(f"Failed to create travel log: {exc}")


@csrf_exempt
@require_POST
def create_safety_report(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        user_id = payload.get("userId")
        if user_id is None:
            return _bad_request("userId is required")

        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO saferoute.safety_reports
                  (user_id, route_id, location_id, description, severity)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
                """,
                [
                    user_id,
                    payload.get("routeId"),
                    payload.get("locationId"),
                    payload.get("description"),
                    payload.get("severity"),
                ],
            )
            safety_report_id = cursor.fetchone()[0]

        return JsonResponse({"id": safety_report_id})
    except Exception as exc:
        return _server_error(f"Failed to create safety report: {exc}")


@csrf_exempt
@require_POST
def create_incident(request: HttpRequest) -> JsonResponse:
    try:
        ensure_schema()
        payload = _decode_request(request)
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO saferoute.incidents
                  (safety_report_id, incident_type, description, location_id, occurred_at)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
                """,
                [
                    payload.get("safetyReportId"),
                    payload.get("incidentType"),
                    payload.get("description"),
                    payload.get("locationId"),
                    payload.get("occurredAt"),
                ],
            )
            incident_id = cursor.fetchone()[0]

        return JsonResponse({"id": incident_id})
    except Exception as exc:
        return _server_error(f"Failed to create incident: {exc}")
