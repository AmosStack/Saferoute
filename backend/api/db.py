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
        CREATE TABLE IF NOT EXISTS saferoute.admins (
          id SERIAL PRIMARY KEY,
          username VARCHAR(120) NOT NULL UNIQUE,
          password_hash VARCHAR(255) NOT NULL,
          role VARCHAR(32) NOT NULL DEFAULT 'super_admin',
          area_level VARCHAR(32),
          area_name VARCHAR(120),
          boundary_min_lat DECIMAL(10, 8),
          boundary_max_lat DECIMAL(10, 8),
          boundary_min_lng DECIMAL(11, 8),
          boundary_max_lng DECIMAL(11, 8),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'super_admin'",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS area_level VARCHAR(32)",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS area_name VARCHAR(120)",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS boundary_min_lat DECIMAL(10, 8)",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS boundary_max_lat DECIMAL(10, 8)",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS boundary_min_lng DECIMAL(11, 8)",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS boundary_max_lng DECIMAL(11, 8)",
        "ALTER TABLE saferoute.admins ADD COLUMN IF NOT EXISTS boundary_geom geometry(Polygon, 4326)",
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
          fare_cost NUMERIC(10, 2),
          waiting_time_minutes INT,
          transfer_count INT,
          safety_assessment JSONB,
          consent_accepted BOOLEAN NOT NULL DEFAULT FALSE,
          started_at TIMESTAMP NOT NULL,
          ended_at TIMESTAMP NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT rating_range CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5))
        )
        """,
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_user_id ON saferoute.recorded_routes(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_created_at ON saferoute.recorded_routes(created_at)",
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_start_geom ON saferoute.recorded_routes USING GIST (start_geom)",
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_end_geom ON saferoute.recorded_routes USING GIST (end_geom)",
        "CREATE INDEX IF NOT EXISTS idx_recorded_routes_route_geom ON saferoute.recorded_routes USING GIST (route_geom)",
        # populate start_geom/end_geom/route_geom from existing numeric fields if missing
        "UPDATE saferoute.recorded_routes SET start_geom = ST_SetSRID(ST_MakePoint(start_longitude::double precision, start_latitude::double precision), 4326) WHERE start_geom IS NULL AND start_latitude IS NOT NULL AND start_longitude IS NOT NULL",
        "UPDATE saferoute.recorded_routes SET end_geom = ST_SetSRID(ST_MakePoint(end_longitude::double precision, end_latitude::double precision), 4326) WHERE end_geom IS NULL AND end_latitude IS NOT NULL AND end_longitude IS NOT NULL",
        "UPDATE saferoute.recorded_routes SET route_geom = ST_SetSRID(ST_MakeLine(ARRAY(SELECT ST_MakePoint((pt->>'lng')::double precision, (pt->>'lat')::double precision) FROM jsonb_array_elements(coordinates) WITH ORDINALITY AS t(pt, idx) ORDER BY idx)), 4326) WHERE route_geom IS NULL AND coordinates IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS idx_admins_boundary_geom ON saferoute.admins USING GIST (boundary_geom)",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS start_location_name TEXT",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS end_location_name TEXT",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS transport_mode TEXT NOT NULL DEFAULT 'walking'",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS fare_cost NUMERIC(10, 2)",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS waiting_time_minutes INT",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS transfer_count INT",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS safety_assessment JSONB",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS consent_accepted BOOLEAN NOT NULL DEFAULT FALSE",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS start_geom geometry(Point, 4326)",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS end_geom geometry(Point, 4326)",
        "ALTER TABLE saferoute.recorded_routes ADD COLUMN IF NOT EXISTS route_geom geometry(LineString, 4326)",
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
