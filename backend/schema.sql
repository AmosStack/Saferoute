-- =========================================
-- CREATE SCHEMA
-- =========================================
CREATE SCHEMA IF NOT EXISTS saferoute;

-- =========================================
-- ENABLE EXTENSION
-- =========================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================
-- USERS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(180) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- populate geometry columns from existing lat/lng and coordinates
UPDATE saferoute.recorded_routes SET start_geom = ST_SetSRID(ST_MakePoint(start_longitude::double precision, start_latitude::double precision), 4326) WHERE start_geom IS NULL AND start_latitude IS NOT NULL AND start_longitude IS NOT NULL;
UPDATE saferoute.recorded_routes SET end_geom = ST_SetSRID(ST_MakePoint(end_longitude::double precision, end_latitude::double precision), 4326) WHERE end_geom IS NULL AND end_latitude IS NOT NULL AND end_longitude IS NOT NULL;
UPDATE saferoute.recorded_routes SET route_geom = ST_SetSRID(ST_MakeLine(ARRAY(SELECT ST_MakePoint((pt->>'lng')::double precision, (pt->>'lat')::double precision) FROM jsonb_array_elements(coordinates) WITH ORDINALITY AS t(pt, idx) ORDER BY idx)), 4326) WHERE route_geom IS NULL AND coordinates IS NOT NULL;

-- spatial indexes
CREATE INDEX IF NOT EXISTS idx_recorded_routes_start_geom ON saferoute.recorded_routes USING GIST (start_geom);
CREATE INDEX IF NOT EXISTS idx_recorded_routes_end_geom ON saferoute.recorded_routes USING GIST (end_geom);
CREATE INDEX IF NOT EXISTS idx_recorded_routes_route_geom ON saferoute.recorded_routes USING GIST (route_geom);
CREATE INDEX IF NOT EXISTS idx_admins_boundary_geom ON saferoute.admins USING GIST (boundary_geom);

-- =========================================
-- TRANSPORT MODES TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.transport_modes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- LOCATIONS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.locations (
    id SERIAL PRIMARY KEY,
    name TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- ROUTES TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INT NOT NULL,
    name TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_routes_user
        FOREIGN KEY (user_id)
        REFERENCES saferoute.users(id)
        ON DELETE CASCADE
);

-- =========================================
-- RECORDED ROUTES TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.recorded_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id INT NOT NULL,

    start_location_name TEXT,
    end_location_name TEXT,

    transport_mode TEXT NOT NULL DEFAULT 'walking',

    start_latitude DECIMAL(10,8) NOT NULL,
    start_longitude DECIMAL(11,8) NOT NULL,

    end_latitude DECIMAL(10,8) NOT NULL,
    end_longitude DECIMAL(11,8) NOT NULL,

    start_geom geometry(Point,4326),
    end_geom geometry(Point,4326),
    route_geom geometry(LineString,4326),

    coordinates JSONB NOT NULL,

    distance_meters DOUBLE PRECISION NOT NULL,
    duration_seconds INT NOT NULL,

    rating INT,
    notes TEXT,
    fare_cost NUMERIC(10,2),
    waiting_time_minutes INT,
    transfer_count INT,
    safety_assessment JSONB,
    consent_accepted BOOLEAN NOT NULL DEFAULT FALSE,

    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP NOT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_recorded_routes_user
        FOREIGN KEY (user_id)
        REFERENCES saferoute.users(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_rating_range
        CHECK (
            rating IS NULL
            OR (rating BETWEEN 1 AND 5)
        )
);

-- =========================================
-- TRAVEL LOGS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.travel_logs (
    id SERIAL PRIMARY KEY,

    user_id INT NOT NULL,
    route_id UUID,
    recorded_route_id UUID,
    transport_mode_id INT,

    started_at TIMESTAMP,
    ended_at TIMESTAMP,

    distance_meters DOUBLE PRECISION,
    duration_seconds INT,

    notes TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_travel_logs_user
        FOREIGN KEY (user_id)
        REFERENCES saferoute.users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_travel_logs_route
        FOREIGN KEY (route_id)
        REFERENCES saferoute.routes(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_travel_logs_recorded_route
        FOREIGN KEY (recorded_route_id)
        REFERENCES saferoute.recorded_routes(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_travel_logs_transport_mode
        FOREIGN KEY (transport_mode_id)
        REFERENCES saferoute.transport_modes(id)
);

-- =========================================
-- SAFETY REPORTS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.safety_reports (
    id SERIAL PRIMARY KEY,

    user_id INT NOT NULL,
    route_id UUID,
    location_id INT,

    description TEXT,
    severity INT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_safety_reports_user
        FOREIGN KEY (user_id)
        REFERENCES saferoute.users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_safety_reports_route
        FOREIGN KEY (route_id)
        REFERENCES saferoute.routes(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_safety_reports_location
        FOREIGN KEY (location_id)
        REFERENCES saferoute.locations(id)
        ON DELETE SET NULL
);

-- =========================================
-- INCIDENTS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS saferoute.incidents (
    id SERIAL PRIMARY KEY,

    safety_report_id INT,
    incident_type TEXT,
    description TEXT,
    location_id INT,

    occurred_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_incidents_safety_report
        FOREIGN KEY (safety_report_id)
        REFERENCES saferoute.safety_reports(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_incidents_location
        FOREIGN KEY (location_id)
        REFERENCES saferoute.locations(id)
        ON DELETE SET NULL
);

-- =========================================
-- INDEXES
-- =========================================
CREATE INDEX IF NOT EXISTS idx_recorded_routes_user_id
ON saferoute.recorded_routes(user_id);

CREATE INDEX IF NOT EXISTS idx_recorded_routes_created_at
ON saferoute.recorded_routes(created_at);

CREATE INDEX IF NOT EXISTS idx_travel_logs_user_id
ON saferoute.travel_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_safety_reports_user_id
ON saferoute.safety_reports(user_id);


CREATE TABLE IF NOT EXISTS saferoute.admins (
    id SERIAL PRIMARY KEY,
    username VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'super_admin',
    area_level VARCHAR(32),
    area_name VARCHAR(120),
    boundary_min_lat DECIMAL(10,8),
    boundary_max_lat DECIMAL(10,8),
    boundary_min_lng DECIMAL(11,8),
    boundary_max_lng DECIMAL(11,8),
    boundary_geom geometry(Polygon,4326),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO saferoute.admins (username, password_hash, role)
VALUES ('admin', 'pbkdf2_sha256$870000$saferoute-admin$YGM/Ri/+IeI1dZFTWtfFrYOIOSV/3THvCtuxis0ClVk=', 'super_admin')
ON CONFLICT (username)
DO UPDATE SET password_hash = EXCLUDED.password_hash, role = EXCLUDED.role;