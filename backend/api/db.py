from django.db import connection


def ensure_schema() -> None:
    statements = [
        "CREATE SCHEMA IF NOT EXISTS saferoute",
        "CREATE EXTENSION IF NOT EXISTS pgcrypto",
        """
        CREATE TABLE IF NOT EXISTS saferoute.users (
          id SERIAL PRIMARY KEY,
          name VARCHAR(120) NOT NULL,
          email VARCHAR(180) NOT NULL UNIQUE,
          password_hash VARCHAR(255) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS saferoute.recorded_routes (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
          start_location_name TEXT,
          end_location_name TEXT,
          transport_mode TEXT NOT NULL DEFAULT 'walking',
          start_latitude DECIMAL(10, 8) NOT NULL,
          start_longitude DECIMAL(11, 8) NOT NULL,
          end_latitude DECIMAL(10, 8) NOT NULL,
          end_longitude DECIMAL(11, 8) NOT NULL,
          coordinates JSONB NOT NULL,
          distance_meters DOUBLE PRECISION NOT NULL,
          duration_seconds INT NOT NULL,
          rating INT,
          notes TEXT,
          started_at TIMESTAMP NOT NULL,
          ended_at TIMESTAMP NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT rating_range CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5))
        )
        """,
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_user_id ON saferoute.recorded_routes(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_created_at ON saferoute.recorded_routes(created_at)",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS start_location_name TEXT",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS end_location_name TEXT",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS transport_mode TEXT NOT NULL DEFAULT 'walking'",
        """
        CREATE TABLE IF NOT EXISTS saferoute.transport_modes (
          id SERIAL PRIMARY KEY,
          name VARCHAR(80) NOT NULL UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS saferoute.locations (
          id SERIAL PRIMARY KEY,
          name TEXT,
          latitude DECIMAL(10,8),
          longitude DECIMAL(11,8),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS saferoute.routes (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
          name TEXT,
          description TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS saferoute.travel_logs (
          id SERIAL PRIMARY KEY,
          user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
          route_id UUID REFERENCES saferoute.routes(id) ON DELETE SET NULL,
          recorded_route_id UUID REFERENCES saferoute.recorded_routes(id) ON DELETE SET NULL,
          transport_mode_id INT REFERENCES saferoute.transport_modes(id),
          started_at TIMESTAMP,
          ended_at TIMESTAMP,
          distance_meters DOUBLE PRECISION,
          duration_seconds INT,
          notes TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS saferoute.safety_reports (
          id SERIAL PRIMARY KEY,
          user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
          route_id UUID REFERENCES saferoute.routes(id) ON DELETE SET NULL,
          location_id INT REFERENCES saferoute.locations(id) ON DELETE SET NULL,
          description TEXT,
          severity INT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS saferoute.incidents (
          id SERIAL PRIMARY KEY,
          safety_report_id INT REFERENCES saferoute.safety_reports(id) ON DELETE CASCADE,
          incident_type TEXT,
          description TEXT,
          location_id INT REFERENCES saferoute.locations(id) ON DELETE SET NULL,
          occurred_at TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        "CREATE INDEX IF NOT EXISTS idx_travel_logs_user_id ON saferoute.travel_logs(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_safety_reports_user_id ON saferoute.safety_reports(user_id)",
    ]

    with connection.cursor() as cursor:
        for statement in statements:
            cursor.execute(statement)
