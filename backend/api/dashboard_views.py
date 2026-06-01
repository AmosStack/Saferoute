import base64
from decimal import Decimal
import json
import logging
import os
from functools import wraps

from django.contrib.auth.hashers import make_password, check_password
from django.core.signing import Signer, BadSignature
from django.db import connection
from django.http import HttpRequest, HttpResponse, HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse
from django.views.decorators.http import require_POST

from .db import ensure_schema

logger = logging.getLogger(__name__)
signer = Signer()
ADMIN_ROLE_CHOICES = (
    ("super_admin", "Super admin"),
    ("analyst", "Analyst"),
    ("reviewer", "Reviewer"),
    ("district_security_officer", "District security officer"),
    ("ward_security_officer", "Ward security officer"),
)
ADMIN_ROLE_VALUES = {choice[0] for choice in ADMIN_ROLE_CHOICES}
ADMIN_AREA_LEVEL_CHOICES = (
    ("district", "District"),
    ("ward", "Ward"),
)
ADMIN_AREA_LEVEL_VALUES = {choice[0] for choice in ADMIN_AREA_LEVEL_CHOICES}


def _dictfetchall(cursor):
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def _dictfetchone(cursor):
    row = cursor.fetchone()
    if row is None:
        return None
    columns = [column[0] for column in cursor.description]
    return dict(zip(columns, row))


def _json_ready(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, str):
        stripped = value.strip()
        if stripped.startswith("[") or stripped.startswith("{"):
            try:
                return _json_ready(json.loads(stripped))
            except json.JSONDecodeError:
                return value
        return value
    if isinstance(value, dict):
        return {key: _json_ready(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_ready(item) for item in value]
    return value


def _current_admin(request: HttpRequest) -> dict | None:
    username_env = os.environ.get("DASHBOARD_USERNAME", "admin")
    password_env = os.environ.get("DASHBOARD_PASSWORD", "admin123")
    header = request.headers.get("Authorization", "")

    def _lookup_admin(username: str) -> dict | None:
        ensure_schema()
        with connection.cursor() as cursor:
            cursor.execute(
                """
                  SELECT username, password_hash, role, area_level, area_name,
                      boundary_min_lat, boundary_max_lat, boundary_min_lng, boundary_max_lng
                FROM saferoute.admins
                WHERE username = %s
                LIMIT 1
                """,
                [username],
            )
            row = cursor.fetchone()
        if not row:
            return None
        return {
            "username": row[0],
            "password_hash": row[1],
            "role": row[2] or "super_admin",
            "area_level": row[3],
            "area_name": row[4],
            "boundary_min_lat": row[5],
            "boundary_max_lat": row[6],
            "boundary_min_lng": row[7],
            "boundary_max_lng": row[8],
        }

    if header.startswith("Basic "):
        try:
            raw = base64.b64decode(header.removeprefix("Basic ").strip()).decode("utf-8")
            supplied_username, supplied_password = raw.split(":", 1)
            admin = _lookup_admin(supplied_username)
            if admin and _password_matches(supplied_password, admin["password_hash"]):
                return admin
            if supplied_username == username_env and supplied_password == password_env:
                return {"username": supplied_username, "password_hash": password_env, "role": "super_admin", "area_level": None, "area_name": None, "boundary_min_lat": None, "boundary_max_lat": None, "boundary_min_lng": None, "boundary_max_lng": None}
        except Exception:
            pass

    signed = request.COOKIES.get("dashboard_signed")
    if signed:
        try:
            unsigned = signer.unsign(signed)
            admin = _lookup_admin(unsigned)
            if admin:
                return admin
            if unsigned == username_env:
                return {"username": unsigned, "password_hash": password_env, "role": "super_admin", "area_level": None, "area_name": None, "boundary_min_lat": None, "boundary_max_lat": None, "boundary_min_lng": None, "boundary_max_lng": None}
        except BadSignature:
            pass

    return None


def _role_permitted(admin_role: str, allowed_roles: set[str] | None) -> bool:
    if not allowed_roles or admin_role == "super_admin":
        return True
    return admin_role in allowed_roles


def _scope_requires_area(role: str) -> bool:
    return role in {"district_security_officer", "ward_security_officer"}


def _scope_sql(admin: dict | None, route_alias: str = "rr", location_alias: str = "l", user_alias: str = "u") -> tuple[str, list[str]]:
    if not admin:
        return "1=1", []

    role = admin.get("role", "super_admin")
    boundary_min_lat = admin.get("boundary_min_lat")
    boundary_max_lat = admin.get("boundary_max_lat")
    boundary_min_lng = admin.get("boundary_min_lng")
    boundary_max_lng = admin.get("boundary_max_lng")

    if role == "super_admin":
        return "1=1", []

    if boundary_min_lat is None or boundary_max_lat is None or boundary_min_lng is None or boundary_max_lng is None:
        return "1=1", []

    params = [
        boundary_min_lat,
        boundary_max_lat,
        boundary_min_lng,
        boundary_max_lng,
        boundary_min_lat,
        boundary_max_lat,
        boundary_min_lng,
        boundary_max_lng,
    ]
    clause = (
        f"((({route_alias}.start_latitude IS NOT NULL AND {route_alias}.start_longitude IS NOT NULL) AND "
        f"{route_alias}.start_latitude BETWEEN %s AND %s AND {route_alias}.start_longitude BETWEEN %s AND %s) OR "
        f"(({route_alias}.end_latitude IS NOT NULL AND {route_alias}.end_longitude IS NOT NULL) AND "
        f"{route_alias}.end_latitude BETWEEN %s AND %s AND {route_alias}.end_longitude BETWEEN %s AND %s))"
    )
    return clause, params


def _admin_scope_params(
    role: str,
    area_level: str | None,
    area_name: str | None,
    boundary_min_lat: str | None,
    boundary_max_lat: str | None,
    boundary_min_lng: str | None,
    boundary_max_lng: str | None,
) -> tuple[str | None, str | None, float | None, float | None, float | None, float | None]:
    normalized_level = (area_level or "").strip().lower() or None
    normalized_name = (area_name or "").strip() or None

    def _parse_boundary(value: str | None, label: str) -> float | None:
        if value is None or value.strip() == "":
            return None
        try:
            return float(value)
        except ValueError as exc:
            raise ValueError(f"{label} must be a valid number.") from exc

    parsed_min_lat = _parse_boundary(boundary_min_lat, "Minimum latitude")
    parsed_max_lat = _parse_boundary(boundary_max_lat, "Maximum latitude")
    parsed_min_lng = _parse_boundary(boundary_min_lng, "Minimum longitude")
    parsed_max_lng = _parse_boundary(boundary_max_lng, "Maximum longitude")

    if _scope_requires_area(role):
        if normalized_level not in ADMIN_AREA_LEVEL_VALUES or not normalized_name:
            raise ValueError("Area level and area name are required for ward and district officers.")
        if None in {parsed_min_lat, parsed_max_lat, parsed_min_lng, parsed_max_lng}:
            raise ValueError("Boundary latitude and longitude values are required for ward and district officers.")
    elif any(value is not None for value in (parsed_min_lat, parsed_max_lat, parsed_min_lng, parsed_max_lng)):
        if None in {parsed_min_lat, parsed_max_lat, parsed_min_lng, parsed_max_lng}:
            raise ValueError("Provide all four boundary values or leave them all blank.")

    if parsed_min_lat is not None and parsed_max_lat is not None and parsed_min_lat > parsed_max_lat:
        raise ValueError("Minimum latitude must be less than or equal to maximum latitude.")
    if parsed_min_lng is not None and parsed_max_lng is not None and parsed_min_lng > parsed_max_lng:
        raise ValueError("Minimum longitude must be less than or equal to maximum longitude.")

    return normalized_level, normalized_name, parsed_min_lat, parsed_max_lat, parsed_min_lng, parsed_max_lng


def _password_matches(raw_password: str, stored_hash: str) -> bool:
    try:
        if check_password(raw_password, stored_hash):
            return True
    except Exception:
        pass

    return raw_password == stored_hash


def _dashboard_auth(view_func=None, *, roles: set[str] | None = None):
    def decorator(func):
        @wraps(func)
        def wrapper(request: HttpRequest, *args, **kwargs):
            admin = _current_admin(request)
            if admin is None:
                accept = request.headers.get("Accept", "")
                if "text/html" in accept:
                    return _redirect("dashboard_login")

                response = HttpResponse("Authentication required", status=401)
                response["WWW-Authenticate"] = 'Basic realm="SafeRoute Admin"'
                return response

            if not _role_permitted(admin.get("role", "super_admin"), roles):
                return HttpResponse("Forbidden", status=403)

            request.safe_route_admin = admin
            return func(request, *args, **kwargs)

        return wrapper

    if view_func is not None and callable(view_func):
        return decorator(view_func)

    return decorator


def _redirect(path_name: str, **params):
    suffix = ""
    if params:
        suffix = "?" + "&".join(f"{key}={value}" for key, value in params.items())
    return HttpResponseRedirect(reverse(path_name) + suffix)


def dashboard_login(request: HttpRequest):
    ensure_schema()
    error = ""
    if request.method == "POST":
        username = request.POST.get("username", "").strip()
        password = request.POST.get("password", "")
        if not username or not password:
            error = "Username and password are required."
        else:
            admin = _current_admin(request)
            if admin is None:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT password_hash, role FROM saferoute.admins WHERE username = %s LIMIT 1", [username])
                    row = cursor.fetchone()
                if row and _password_matches(password, row[0]):
                    admin = {"username": username, "password_hash": row[0], "role": row[1] or "super_admin"}
                elif username == os.environ.get("DASHBOARD_USERNAME", "admin") and password == os.environ.get("DASHBOARD_PASSWORD", "admin123"):
                    admin = {"username": username, "password_hash": password, "role": "super_admin"}

            if admin is not None:
                response = _redirect("dashboard_home")
                response.set_cookie("dashboard_signed", signer.sign(username), httponly=True, max_age=60 * 60 * 24)
                return response
            else:
                error = "Invalid username or password."

    return render(request, "dashboard/login.html", {"error": error})


def dashboard_logout(request: HttpRequest):
    response = _redirect("dashboard_login")
    response.delete_cookie("dashboard_signed")
    return response


@_dashboard_auth(roles={"super_admin"})
def admins_list(request: HttpRequest):
    ensure_schema()
    query = request.GET.get("q", "").strip()
    params = []
    where = ""
    if query:
        where = "WHERE username ILIKE %s OR role ILIKE %s"
        params = [f"%{query}%", f"%{query}%"]

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT id, username, role, area_level, area_name,
                   boundary_min_lat, boundary_max_lat, boundary_min_lng, boundary_max_lng,
                   created_at
            FROM saferoute.admins
            {where}
            ORDER BY created_at DESC, username ASC
            """,
            params,
        )
        admins = _dictfetchall(cursor)

    return render(
        request,
        "dashboard/admins.html",
        {
            "active": "admins",
            "admins": admins,
            "roles": ADMIN_ROLE_CHOICES,
            "area_levels": ADMIN_AREA_LEVEL_CHOICES,
            "query": query,
            "message": request.GET.get("message", ""),
            "error": request.GET.get("error", ""),
        },
    )


@_dashboard_auth(roles={"super_admin"})
def admin_create(request: HttpRequest):
    if request.method != "POST":
        return _redirect("admins_list")

    ensure_schema()
    username = request.POST.get("username", "").strip().lower()
    password = request.POST.get("password", "")
    role = request.POST.get("role", "super_admin").strip()
    area_level = request.POST.get("area_level", "").strip().lower() or None
    area_name = request.POST.get("area_name", "").strip() or None
    boundary_min_lat = request.POST.get("boundary_min_lat", "").strip() or None
    boundary_max_lat = request.POST.get("boundary_max_lat", "").strip() or None
    boundary_min_lng = request.POST.get("boundary_min_lng", "").strip() or None
    boundary_max_lng = request.POST.get("boundary_max_lng", "").strip() or None

    if not username or len(password) < 8:
        return _redirect("admins_list", error="Username and an 8 character password are required.")
    if role not in ADMIN_ROLE_VALUES:
        return _redirect("admins_list", error="Choose a valid admin role.")
    try:
        area_level, area_name, boundary_min_lat, boundary_max_lat, boundary_min_lng, boundary_max_lng = _admin_scope_params(
            role,
            area_level,
            area_name,
            boundary_min_lat,
            boundary_max_lat,
            boundary_min_lng,
            boundary_max_lng,
        )
    except ValueError as exc:
        return _redirect("admins_list", error=str(exc))

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM saferoute.admins WHERE username = %s LIMIT 1",
                [username],
            )
            if cursor.fetchone():
                return _redirect("admins_list", error="An admin with that username already exists.")

            cursor.execute(
                """
                INSERT INTO saferoute.admins (
                    username, password_hash, role, area_level, area_name,
                    boundary_min_lat, boundary_max_lat, boundary_min_lng, boundary_max_lng
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                [
                    username,
                    make_password(password),
                    role,
                    area_level,
                    area_name,
                    boundary_min_lat,
                    boundary_max_lat,
                    boundary_min_lng,
                    boundary_max_lng,
                ],
            )
        return _redirect("admins_list", message="Admin created.")
    except Exception as exc:
        return _redirect("admins_list", error=str(exc))


@_dashboard_auth(roles={"super_admin"})
def admin_update(request: HttpRequest, admin_id: int):
    if request.method != "POST":
        return _redirect("admins_list")

    ensure_schema()
    role = request.POST.get("role", "").strip()
    area_level = request.POST.get("area_level", "").strip().lower() or None
    area_name = request.POST.get("area_name", "").strip() or None
    boundary_min_lat = request.POST.get("boundary_min_lat", "").strip() or None
    boundary_max_lat = request.POST.get("boundary_max_lat", "").strip() or None
    boundary_min_lng = request.POST.get("boundary_min_lng", "").strip() or None
    boundary_max_lng = request.POST.get("boundary_max_lng", "").strip() or None
    if role not in ADMIN_ROLE_VALUES:
        return _redirect("admins_list", error="Choose a valid admin role.")
    try:
        area_level, area_name, boundary_min_lat, boundary_max_lat, boundary_min_lng, boundary_max_lng = _admin_scope_params(
            role,
            area_level,
            area_name,
            boundary_min_lat,
            boundary_max_lat,
            boundary_min_lng,
            boundary_max_lng,
        )
    except ValueError as exc:
        return _redirect("admins_list", error=str(exc))

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT username, role, area_level, area_name, boundary_min_lat, boundary_max_lat, boundary_min_lng, boundary_max_lng FROM saferoute.admins WHERE id = %s",
                [admin_id],
            )
            row = cursor.fetchone()
            if not row:
                return _redirect("admins_list", error="Admin not found.")

            current_role = row[1] or "super_admin"
            if current_role == "super_admin" and role != "super_admin":
                cursor.execute("SELECT COUNT(*) FROM saferoute.admins WHERE role = 'super_admin'")
                super_admin_count = cursor.fetchone()[0]
                if super_admin_count <= 1:
                    return _redirect("admins_list", error="At least one super admin must remain.")

            cursor.execute(
                """
                UPDATE saferoute.admins
                SET role = %s,
                    area_level = %s,
                    area_name = %s,
                    boundary_min_lat = %s,
                    boundary_max_lat = %s,
                    boundary_min_lng = %s,
                    boundary_max_lng = %s
                WHERE id = %s
                """,
                [
                    role,
                    area_level,
                    area_name,
                    boundary_min_lat,
                    boundary_max_lat,
                    boundary_min_lng,
                    boundary_max_lng,
                    admin_id,
                ],
            )
        return _redirect("admins_list", message="Admin role updated.")
    except Exception as exc:
        return _redirect("admins_list", error=str(exc))


def _metrics(scope_sql: str = "1=1", scope_params: list[str] | None = None):
    ensure_schema()
    scope_params = scope_params or []
    with connection.cursor() as cursor:
        cursor.execute(
            (
                """
                WITH scoped_routes AS (
                    SELECT rr.*
                    FROM saferoute.recorded_routes rr
                    """
                + (f"WHERE {scope_sql}" if scope_sql != "1=1" else "")
                + """
                )
                SELECT
                    (SELECT COUNT(DISTINCT user_id) FROM scoped_routes) AS users,
                    (SELECT COUNT(*) FROM scoped_routes) AS recorded_routes,
                    (SELECT COUNT(*) FROM saferoute.travel_logs tl WHERE tl.recorded_route_id IN (SELECT id FROM scoped_routes)) AS travel_logs,
                    COALESCE((SELECT SUM(distance_meters) FROM scoped_routes), 0) AS distance_meters,
                    COALESCE((SELECT SUM(duration_seconds) FROM scoped_routes), 0) AS duration_seconds,
                    COALESCE((SELECT ROUND(AVG(rating)::numeric, 2) FROM scoped_routes WHERE rating IS NOT NULL), 0) AS average_rating,
                    (SELECT COUNT(*) FROM saferoute.safety_reports sr WHERE sr.route_id IN (SELECT id FROM scoped_routes)) AS safety_reports,
                    (SELECT COUNT(*) FROM saferoute.incidents i WHERE i.safety_report_id IN (
                        SELECT sr.id
                        FROM saferoute.safety_reports sr
                        WHERE sr.route_id IN (SELECT id FROM scoped_routes)
                    )) AS incidents
                """
            )
        )
        row = _dictfetchone(cursor)

    row["distance_km"] = round(float(row["distance_meters"] or 0) / 1000, 2)
    row["duration_hours"] = round(float(row["duration_seconds"] or 0) / 3600, 1)
    return row


def _recent_activity_rows(limit: int = 8, scope_sql: str = "1=1", scope_params: list[str] | None = None):
    scope_params = scope_params or []
    with connection.cursor() as cursor:
        scope_where = f"AND {scope_sql}" if scope_sql != "1=1" else ""
        cursor.execute(
            """
            SELECT *
            FROM (
                SELECT
                    'Recorded route' AS source,
                    rr.id::text AS id,
                    u.name AS user_name,
                    u.email,
                    rr.start_location_name,
                    rr.end_location_name,
                    rr.transport_mode,
                    rr.distance_meters,
                    rr.duration_seconds,
                    rr.rating,
                    rr.started_at,
                    rr.ended_at,
                    rr.created_at,
                    rr.coordinates
                FROM saferoute.recorded_routes rr
                JOIN saferoute.users u ON u.id = rr.user_id
                WHERE 1=1
                """ + scope_where + """

                UNION ALL

                SELECT
                    'Travel log' AS source,
                    tl.id::text AS id,
                    u.name AS user_name,
                    u.email,
                    COALESCE(rr.start_location_name, 'Unknown start') AS start_location_name,
                    COALESCE(rr.end_location_name, 'Unknown end') AS end_location_name,
                    COALESCE(tm.name, rr.transport_mode, 'unknown') AS transport_mode,
                    COALESCE(tl.distance_meters, rr.distance_meters, 0) AS distance_meters,
                    COALESCE(tl.duration_seconds, rr.duration_seconds, 0) AS duration_seconds,
                    rr.rating,
                    COALESCE(tl.started_at, rr.started_at, tl.created_at) AS started_at,
                    COALESCE(tl.ended_at, rr.ended_at, tl.created_at) AS ended_at,
                    COALESCE(tl.created_at, rr.created_at) AS created_at,
                    rr.coordinates
                FROM saferoute.travel_logs tl
                JOIN saferoute.users u ON u.id = tl.user_id
                LEFT JOIN saferoute.recorded_routes rr ON rr.id = tl.recorded_route_id
                LEFT JOIN saferoute.transport_modes tm ON tm.id = tl.transport_mode_id
                WHERE tl.recorded_route_id IS NULL
                """ + scope_where + """
            ) activity
            ORDER BY created_at DESC
            LIMIT %s
            """,
            scope_params + [limit],
        )
        rows = _dictfetchall(cursor)

    for row in rows:
        row["coordinates"] = _json_ready(row.get("coordinates") or [])
    return rows


def _route_map_rows(limit: int = 20, scope_sql: str = "1=1", scope_params: list[str] | None = None):
    scope_params = scope_params or []
    with connection.cursor() as cursor:
        scope_where = f"WHERE {scope_sql}" if scope_sql != "1=1" else ""
        cursor.execute(
            """
            SELECT rr.id::text AS id, u.name AS user_name, rr.start_location_name,
                   rr.end_location_name, rr.transport_mode, rr.distance_meters,
                   rr.duration_seconds, rr.rating, rr.start_latitude, rr.start_longitude,
                   rr.end_latitude, rr.end_longitude, rr.coordinates, rr.created_at
            FROM saferoute.recorded_routes rr
            JOIN saferoute.users u ON u.id = rr.user_id
            """ + scope_where + """
            ORDER BY rr.created_at DESC
            LIMIT %s
            """,
            scope_params + [limit],
        )
        rows = _dictfetchall(cursor)

    for row in rows:
        row["coordinates"] = _json_ready(row.get("coordinates") or [])
        row["start_latitude"] = _json_ready(row.get("start_latitude"))
        row["start_longitude"] = _json_ready(row.get("start_longitude"))
        row["end_latitude"] = _json_ready(row.get("end_latitude"))
        row["end_longitude"] = _json_ready(row.get("end_longitude"))
    return rows


def _complaint_map_rows(limit: int = 100, scope_sql: str = "1=1", scope_params: list[str] | None = None):
    scope_params = scope_params or []
    with connection.cursor() as cursor:
        scope_where = f"AND {scope_sql}" if scope_sql != "1=1" else ""
        cursor.execute(
            """
            WITH incident_points AS (
                SELECT
                    location_id,
                    incident_type,
                    description,
                    created_at
                FROM saferoute.incidents
                WHERE location_id IS NOT NULL
                """ + scope_where + """
            )
            SELECT
                l.id AS location_id,
                COALESCE(l.name, 'Reported location') AS location_name,
                l.latitude,
                l.longitude,
                COUNT(*) AS complaint_count,
                COUNT(*) FILTER (
                    WHERE COALESCE(ip.incident_type, '') !~* '^sos$'
                ) AS reported_incidents,
                COUNT(*) FILTER (
                    WHERE COALESCE(ip.incident_type, '') ~* '^sos$'
                ) AS sos_sent,
                MAX(ip.created_at) AS latest_created_at,
                MAX(description) AS sample_description,
                MAX(ip.incident_type) AS sample_incident_type
            FROM incident_points ip
            JOIN saferoute.locations l ON l.id = ip.location_id
            GROUP BY l.id, l.name, l.latitude, l.longitude
            ORDER BY complaint_count DESC, latest_created_at DESC
            LIMIT %s
            """,
            scope_params + [limit],
        )
        rows = _dictfetchall(cursor)

    for row in rows:
        row["latitude"] = _json_ready(row.get("latitude"))
        row["longitude"] = _json_ready(row.get("longitude"))
    return rows


def _safe_dashboard_rows(label: str, callback):
    try:
        return callback()
    except Exception:
        logger.exception("Dashboard overview widget failed: %s", label)
        return []


def _admin_scope_context(request: HttpRequest) -> dict:
    admin = getattr(request, "safe_route_admin", None)
    scope_sql, scope_params = _scope_sql(admin)
    return {"admin": admin, "scope_sql": scope_sql, "scope_params": scope_params}


@_dashboard_auth
def dashboard_home(request: HttpRequest):
    ensure_schema()
    scope = _admin_scope_context(request)
    scope_clause = f"WHERE {scope['scope_sql']}" if scope["scope_sql"] != "1=1" else ""
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT rr.transport_mode, COUNT(*) AS route_count,
                   COALESCE(SUM(rr.distance_meters), 0) AS distance_meters
            FROM saferoute.recorded_routes rr
            """ + scope_clause + """
            GROUP BY rr.transport_mode
            ORDER BY route_count DESC, rr.transport_mode
            LIMIT 6
            """
        )
        mode_rows = _dictfetchall(cursor)

    max_count = max([row["route_count"] for row in mode_rows] or [1])
    for row in mode_rows:
        row["width"] = int((row["route_count"] / max_count) * 100)

    recent_routes = _safe_dashboard_rows("recent activity", lambda: _recent_activity_rows(scope_sql=scope["scope_sql"], scope_params=scope["scope_params"]))
    route_map_data = _safe_dashboard_rows("route map", lambda: _route_map_rows(scope_sql=scope["scope_sql"], scope_params=scope["scope_params"]))
    complaint_map_data = _safe_dashboard_rows("complaint map", lambda: _complaint_map_rows(scope_sql=scope["scope_sql"], scope_params=scope["scope_params"]))

    return render(
        request,
        "dashboard/home.html",
        {
            "active": "dashboard",
            "metrics": _metrics(scope["scope_sql"], scope["scope_params"]),
            "recent_routes": recent_routes,
            "mode_rows": mode_rows,
            "route_map_data": route_map_data,
            "complaint_map_data": complaint_map_data,
        },
    )


@_dashboard_auth(roles={"super_admin", "analyst"})
def users_list(request: HttpRequest):
    ensure_schema()
    query = request.GET.get("q", "").strip()
    scope = _admin_scope_context(request)
    params = []
    where = ""
    if query:
        where = "WHERE name ILIKE %s OR email ILIKE %s"
        params = [f"%{query}%", f"%{query}%"]

    scope_where = ""
    if scope["scope_sql"] != "1=1":
        scope_where = f"AND {scope['scope_sql']}"
        params.extend(scope["scope_params"])

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT u.id, u.name, u.email, u.created_at,
                   COUNT(rr.id) AS route_count,
                   COALESCE(SUM(rr.distance_meters), 0) AS distance_meters
            FROM saferoute.users u
            LEFT JOIN saferoute.recorded_routes rr ON rr.user_id = u.id {scope_where}
            {where}
            GROUP BY u.id, u.name, u.email, u.created_at
            ORDER BY u.created_at DESC
            LIMIT 200
            """,
            params,
        )
        users = _dictfetchall(cursor)

    return render(
        request,
        "dashboard/users.html",
        {
            "active": "users",
            "users": users,
            "query": query,
            "message": request.GET.get("message", ""),
            "error": request.GET.get("error", ""),
        },
    )


@_dashboard_auth(roles={"super_admin"})
def user_create(request: HttpRequest):
    if request.method == "POST":
        ensure_schema()
        name = request.POST.get("name", "").strip()
        email = request.POST.get("email", "").strip().lower()
        password = request.POST.get("password", "")

        if not name or not email or len(password) < 8:
            return _redirect("users_list", error="Name, email, and an 8 character password are required.")

        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO saferoute.users (name, email, password_hash)
                    VALUES (%s, %s, %s)
                    """,
                    [name, email, make_password(password)],
                )
            return _redirect("users_list", message="User created.")
        except Exception as exc:
            return _redirect("users_list", error=str(exc))

    return render(request, "dashboard/user_form.html", {"active": "users", "mode": "Create", "user": {}})


@_dashboard_auth(roles={"super_admin"})
def user_edit(request: HttpRequest, user_id: int):
    ensure_schema()
    if request.method == "POST":
        name = request.POST.get("name", "").strip()
        email = request.POST.get("email", "").strip().lower()
        password = request.POST.get("password", "")

        if not name or not email:
            return _redirect("users_list", error="Name and email are required.")

        try:
            with connection.cursor() as cursor:
                if password:
                    if len(password) < 8:
                        return _redirect("users_list", error="Password must be at least 8 characters.")
                    cursor.execute(
                        "UPDATE saferoute.users SET name = %s, email = %s, password_hash = %s WHERE id = %s",
                        [name, email, make_password(password), user_id],
                    )
                else:
                    cursor.execute(
                        "UPDATE saferoute.users SET name = %s, email = %s WHERE id = %s",
                        [name, email, user_id],
                    )
            return _redirect("users_list", message="User updated.")
        except Exception as exc:
            return _redirect("users_list", error=str(exc))

    with connection.cursor() as cursor:
        cursor.execute("SELECT id, name, email, created_at FROM saferoute.users WHERE id = %s", [user_id])
        user = _dictfetchone(cursor)

    if not user:
        return _redirect("users_list", error="User not found.")

    return render(request, "dashboard/user_form.html", {"active": "users", "mode": "Edit", "user": user})


@_dashboard_auth(roles={"super_admin"})
@require_POST
def user_delete(request: HttpRequest, user_id: int):
    ensure_schema()
    with connection.cursor() as cursor:
        cursor.execute("DELETE FROM saferoute.users WHERE id = %s", [user_id])
    return _redirect("users_list", message="User deleted.")


@_dashboard_auth(roles={"super_admin", "analyst", "reviewer"})
def routes_list(request: HttpRequest):
    ensure_schema()
    scope = _admin_scope_context(request)
    mode = request.GET.get("mode", "").strip()
    query = request.GET.get("q", "").strip()
    params = []
    clauses = []
    if mode:
        clauses.append("rr.transport_mode = %s")
        params.append(mode)
    if query:
        clauses.append("(u.name ILIKE %s OR rr.start_location_name ILIKE %s OR rr.end_location_name ILIKE %s)")
        params.extend([f"%{query}%", f"%{query}%", f"%{query}%"])
    if scope["scope_sql"] != "1=1":
        clauses.append(scope["scope_sql"])
        params.extend(scope["scope_params"])
    where = "WHERE " + " AND ".join(clauses) if clauses else ""

    with connection.cursor() as cursor:
        cursor.execute("SELECT DISTINCT transport_mode FROM saferoute.recorded_routes ORDER BY transport_mode")
        modes = [row[0] for row in cursor.fetchall()]
        cursor.execute(
            f"""
            SELECT rr.id, u.name AS user_name, u.email, rr.start_location_name, rr.end_location_name,
                   rr.transport_mode, rr.distance_meters, rr.duration_seconds, rr.rating,
                   rr.started_at, rr.ended_at, rr.created_at
            FROM saferoute.recorded_routes rr
            JOIN saferoute.users u ON u.id = rr.user_id
            {where}
            ORDER BY rr.created_at DESC
            LIMIT 200
            """,
            params,
        )
        routes = _dictfetchall(cursor)

    return render(
        request,
        "dashboard/routes.html",
        {"active": "routes", "routes": routes, "modes": modes, "selected_mode": mode, "query": query},
    )


@_dashboard_auth(roles={"super_admin", "analyst", "reviewer"})
def route_detail(request: HttpRequest, route_id):
    ensure_schema()
    scope = _admin_scope_context(request)
    scope_clause = f" AND {scope['scope_sql']}" if scope["scope_sql"] != "1=1" else ""
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT rr.*, u.name AS user_name, u.email
            FROM saferoute.recorded_routes rr
            JOIN saferoute.users u ON u.id = rr.user_id
            WHERE rr.id = %s
            """ + scope_clause,
            [str(route_id)] + scope["scope_params"],
        )
        route = _dictfetchone(cursor)

    if not route:
        if scope["scope_sql"] != "1=1":
            return _redirect("routes_list", error="This route is outside your assigned boundary.")
        return _redirect("routes_list")

    coordinates = _json_ready(route.get("coordinates") or [])
    if not isinstance(coordinates, list):
        coordinates = []
    return render(
        request,
        "dashboard/route_detail.html",
        {
            "active": "routes",
            "route": route,
            "coordinates": coordinates[:25],
            "point_count": len(coordinates),
            "route_map_data": {
                "id": str(route["id"]),
                "user_name": route.get("user_name"),
                "start_location_name": route.get("start_location_name"),
                "end_location_name": route.get("end_location_name"),
                "transport_mode": route.get("transport_mode"),
                "start_latitude": _json_ready(route.get("start_latitude")),
                "start_longitude": _json_ready(route.get("start_longitude")),
                "end_latitude": _json_ready(route.get("end_latitude")),
                "end_longitude": _json_ready(route.get("end_longitude")),
                "coordinates": _json_ready(coordinates),
            },
        },
    )


@_dashboard_auth(roles={"super_admin", "analyst"})
def analytics(request: HttpRequest):
    ensure_schema()
    scope = _admin_scope_context(request)
    scope_clause = f"WHERE {scope['scope_sql']}" if scope["scope_sql"] != "1=1" else ""
    with connection.cursor() as cursor:
        cursor.execute(
         """
         SELECT rr.transport_mode, COUNT(*) AS route_count,
             COALESCE(SUM(rr.distance_meters), 0) AS distance_meters,
             COALESCE(ROUND(AVG(rr.duration_seconds)::numeric), 0) AS average_duration,
             COALESCE(ROUND(AVG(rr.rating)::numeric, 2), 0) AS average_rating
         FROM saferoute.recorded_routes rr
         """ + scope_clause + """
         GROUP BY rr.transport_mode
         ORDER BY route_count DESC
         """
        )
        mode_rows = _dictfetchall(cursor)

        cursor.execute(
         """
         SELECT DATE(rr.created_at) AS travel_day, COUNT(*) AS route_count,
             COALESCE(SUM(rr.distance_meters), 0) AS distance_meters
         FROM saferoute.recorded_routes rr
         """ + scope_clause + """
         GROUP BY DATE(rr.created_at)
         ORDER BY travel_day DESC
         LIMIT 14
         """
        )
        daily_rows = _dictfetchall(cursor)

        cursor.execute(
         """
         SELECT u.name, u.email, COUNT(rr.id) AS route_count,
             COALESCE(SUM(rr.distance_meters), 0) AS distance_meters
         FROM saferoute.users u
         JOIN saferoute.recorded_routes rr ON rr.user_id = u.id
         """ + scope_clause + """
         GROUP BY u.id, u.name, u.email
         ORDER BY distance_meters DESC
         LIMIT 10
         """
        )
        top_users = _dictfetchall(cursor)

    max_mode = max([row["route_count"] for row in mode_rows] or [1])
    for row in mode_rows:
        row["width"] = int((row["route_count"] / max_mode) * 100)
        row["distance_km"] = round(float(row["distance_meters"] or 0) / 1000, 2)

    max_daily = max([row["route_count"] for row in daily_rows] or [1])
    for row in daily_rows:
        row["width"] = int((row["route_count"] / max_daily) * 100)
        row["distance_km"] = round(float(row["distance_meters"] or 0) / 1000, 2)

    for row in top_users:
        row["distance_km"] = round(float(row["distance_meters"] or 0) / 1000, 2)

    return render(
        request,
        "dashboard/analytics.html",
        {
            "active": "analytics",
            "metrics": _metrics(scope["scope_sql"], scope["scope_params"]),
            "mode_rows": mode_rows,
            "daily_rows": daily_rows,
            "top_users": top_users,
        },
    )
