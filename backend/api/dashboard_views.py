import base64
import json
import os
from functools import wraps

from django.contrib.auth.hashers import make_password
from django.db import connection
from django.http import HttpRequest, HttpResponse, HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse
from django.views.decorators.http import require_POST

from .db import ensure_schema


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
    if isinstance(value, dict):
        return {key: _json_ready(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_ready(item) for item in value]
    return value


def _dashboard_auth(view_func):
    @wraps(view_func)
    def wrapper(request: HttpRequest, *args, **kwargs):
        username = os.environ.get("DASHBOARD_USERNAME", "admin")
        password = os.environ.get("DASHBOARD_PASSWORD", "admin123")
        header = request.headers.get("Authorization", "")

        if header.startswith("Basic "):
            try:
                raw = base64.b64decode(header.removeprefix("Basic ").strip()).decode("utf-8")
                supplied_username, supplied_password = raw.split(":", 1)
                if supplied_username == username and supplied_password == password:
                    return view_func(request, *args, **kwargs)
            except Exception:
                pass

        response = HttpResponse("Authentication required", status=401)
        response["WWW-Authenticate"] = 'Basic realm="SafeRoute Admin"'
        return response

    return wrapper


def _redirect(path_name: str, **params):
    suffix = ""
    if params:
        suffix = "?" + "&".join(f"{key}={value}" for key, value in params.items())
    return HttpResponseRedirect(reverse(path_name) + suffix)


def _metrics():
    ensure_schema()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
              (SELECT COUNT(*) FROM saferoute.users) AS users,
              (SELECT COUNT(*) FROM saferoute.recorded_routes) AS recorded_routes,
                            (SELECT COUNT(*) FROM saferoute.travel_logs) AS travel_logs,
              COALESCE((SELECT SUM(distance_meters) FROM saferoute.recorded_routes), 0) AS distance_meters,
              COALESCE((SELECT SUM(duration_seconds) FROM saferoute.recorded_routes), 0) AS duration_seconds,
              COALESCE((SELECT ROUND(AVG(rating)::numeric, 2) FROM saferoute.recorded_routes WHERE rating IS NOT NULL), 0) AS average_rating,
                            (SELECT COUNT(*) FROM saferoute.safety_reports) AS safety_reports,
                            (SELECT COUNT(*) FROM saferoute.incidents) AS incidents
            """
        )
        row = _dictfetchone(cursor)

    row["distance_km"] = round(float(row["distance_meters"] or 0) / 1000, 2)
    row["duration_hours"] = round(float(row["duration_seconds"] or 0) / 3600, 1)
    return row


def _recent_activity_rows(limit: int = 8):
        with connection.cursor() as cursor:
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
                        ) activity
                        ORDER BY created_at DESC
                        LIMIT %s
                        """,
                        [limit],
                )
                rows = _dictfetchall(cursor)

        for row in rows:
                row["coordinates"] = _json_ready(row.get("coordinates") or [])
        return rows


def _route_map_rows(limit: int = 20):
        with connection.cursor() as cursor:
                cursor.execute(
                        """
                        SELECT rr.id::text AS id, u.name AS user_name, rr.start_location_name,
                                     rr.end_location_name, rr.transport_mode, rr.distance_meters,
                                     rr.duration_seconds, rr.rating, rr.start_latitude, rr.start_longitude,
                                     rr.end_latitude, rr.end_longitude, rr.coordinates, rr.created_at
                        FROM saferoute.recorded_routes rr
                        JOIN saferoute.users u ON u.id = rr.user_id
                        ORDER BY rr.created_at DESC
                        LIMIT %s
                        """,
                        [limit],
                )
                rows = _dictfetchall(cursor)

        for row in rows:
                row["coordinates"] = _json_ready(row.get("coordinates") or [])
                row["start_latitude"] = _json_ready(row.get("start_latitude"))
                row["start_longitude"] = _json_ready(row.get("start_longitude"))
                row["end_latitude"] = _json_ready(row.get("end_latitude"))
                row["end_longitude"] = _json_ready(row.get("end_longitude"))
        return rows


def _complaint_map_rows(limit: int = 100):
        with connection.cursor() as cursor:
                cursor.execute(
                        """
                        WITH complaint_points AS (
                            SELECT
                                location_id,
                                'safety_report' AS complaint_type,
                                description,
                                severity,
                                created_at
                            FROM saferoute.safety_reports
                            WHERE location_id IS NOT NULL

                            UNION ALL

                            SELECT
                                location_id,
                                'incident' AS complaint_type,
                                description,
                                NULL AS severity,
                                created_at
                            FROM saferoute.incidents
                            WHERE location_id IS NOT NULL
                        )
                        SELECT
                            l.id AS location_id,
                            COALESCE(l.name, 'Reported location') AS location_name,
                            l.latitude,
                            l.longitude,
                            COUNT(*) AS complaint_count,
                            COUNT(*) FILTER (WHERE complaint_type = 'safety_report') AS safety_reports,
                            COUNT(*) FILTER (WHERE complaint_type = 'incident') AS incidents,
                            MAX(created_at) AS latest_created_at,
                            MAX(description) AS sample_description,
                            MAX(severity) AS max_severity
                        FROM complaint_points cp
                        JOIN saferoute.locations l ON l.id = cp.location_id
                        GROUP BY l.id, l.name, l.latitude, l.longitude
                        ORDER BY complaint_count DESC, latest_created_at DESC
                        LIMIT %s
                        """,
                        [limit],
                )
                rows = _dictfetchall(cursor)

        for row in rows:
                row["latitude"] = _json_ready(row.get("latitude"))
                row["longitude"] = _json_ready(row.get("longitude"))
        return rows


@_dashboard_auth
def dashboard_home(request: HttpRequest):
    ensure_schema()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT transport_mode, COUNT(*) AS route_count,
                   COALESCE(SUM(distance_meters), 0) AS distance_meters
            FROM saferoute.recorded_routes
            GROUP BY transport_mode
            ORDER BY route_count DESC, transport_mode
            LIMIT 6
            """
        )
        mode_rows = _dictfetchall(cursor)

    max_count = max([row["route_count"] for row in mode_rows] or [1])
    for row in mode_rows:
        row["width"] = int((row["route_count"] / max_count) * 100)

    recent_routes = _recent_activity_rows()
    route_map_data = _route_map_rows()
    complaint_map_data = _complaint_map_rows()

    return render(
        request,
        "dashboard/home.html",
        {
            "active": "dashboard",
            "metrics": _metrics(),
            "recent_routes": recent_routes,
            "mode_rows": mode_rows,
            "route_map_data": route_map_data,
            "complaint_map_data": complaint_map_data,
        },
    )


@_dashboard_auth
def users_list(request: HttpRequest):
    ensure_schema()
    query = request.GET.get("q", "").strip()
    params = []
    where = ""
    if query:
        where = "WHERE name ILIKE %s OR email ILIKE %s"
        params = [f"%{query}%", f"%{query}%"]

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT u.id, u.name, u.email, u.created_at,
                   COUNT(rr.id) AS route_count,
                   COALESCE(SUM(rr.distance_meters), 0) AS distance_meters
            FROM saferoute.users u
            LEFT JOIN saferoute.recorded_routes rr ON rr.user_id = u.id
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


@_dashboard_auth
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


@_dashboard_auth
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


@_dashboard_auth
@require_POST
def user_delete(request: HttpRequest, user_id: int):
    ensure_schema()
    with connection.cursor() as cursor:
        cursor.execute("DELETE FROM saferoute.users WHERE id = %s", [user_id])
    return _redirect("users_list", message="User deleted.")


@_dashboard_auth
def routes_list(request: HttpRequest):
    ensure_schema()
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


@_dashboard_auth
def route_detail(request: HttpRequest, route_id):
    ensure_schema()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT rr.*, u.name AS user_name, u.email
            FROM saferoute.recorded_routes rr
            JOIN saferoute.users u ON u.id = rr.user_id
            WHERE rr.id = %s
            """,
            [str(route_id)],
        )
        route = _dictfetchone(cursor)

    if not route:
        return _redirect("routes_list")

    coordinates = route.get("coordinates") or []
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


@_dashboard_auth
def analytics(request: HttpRequest):
    ensure_schema()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT transport_mode, COUNT(*) AS route_count,
                   COALESCE(SUM(distance_meters), 0) AS distance_meters,
                   COALESCE(ROUND(AVG(duration_seconds)::numeric), 0) AS average_duration,
                   COALESCE(ROUND(AVG(rating)::numeric, 2), 0) AS average_rating
            FROM saferoute.recorded_routes
            GROUP BY transport_mode
            ORDER BY route_count DESC
            """
        )
        mode_rows = _dictfetchall(cursor)

        cursor.execute(
            """
            SELECT DATE(created_at) AS travel_day, COUNT(*) AS route_count,
                   COALESCE(SUM(distance_meters), 0) AS distance_meters
            FROM saferoute.recorded_routes
            GROUP BY DATE(created_at)
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
            "metrics": _metrics(),
            "mode_rows": mode_rows,
            "daily_rows": daily_rows,
            "top_users": top_users,
        },
    )
