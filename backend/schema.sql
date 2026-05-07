CREATE SCHEMA IF NOT EXISTS saferoute;

CREATE TABLE IF NOT EXISTS saferoute.users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS saferoute.recorded_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
  start_location_name TEXT,
  end_location_name TEXT,
  start_latitude DECIMAL(10, 8) NOT NULL,
  start_longitude DECIMAL(11, 8) NOT NULL,
  end_latitude DECIMAL(10, 8) NOT NULL,
  end_longitude DECIMAL(11, 8) NOT NULL,
  coordinates JSONB NOT NULL, -- Array of {lat, lng} points
  distance_meters DOUBLE PRECISION NOT NULL,
  duration_seconds INT NOT NULL,
  rating INT, -- 1-5 stars
  notes TEXT,
  started_at TIMESTAMP NOT NULL,
  ended_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT rating_range CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5))
);

CREATE INDEX IF NOT EXISTS idx_recorded_routes_user_id ON saferoute.recorded_routes(user_id);
CREATE INDEX IF NOT EXISTS idx_recorded_routes_created_at ON saferoute.recorded_routes(created_at);