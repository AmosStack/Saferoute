import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

late Connection _db;

Future<void> main() async {
  // Initialize database connection using postgres v3 API
  _db = await Connection.open(
    Endpoint(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.tryParse(Platform.environment['DB_PORT'] ?? '') ?? 5432,
      database: Platform.environment['DB_NAME'] ?? 'saferoute',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password: Platform.environment['DB_PASSWORD'] ?? 'postgres',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
  await _ensureSchema();

  final router = Router()
    ..get('/health', _health)
    ..post('/auth/register', _register)
    ..post('/auth/login', _login)
    ..post('/routes/record', _recordRoute)
    ..get('/routes/user/<userId>', _getUserRoutes)
    ..post('/transport-modes', _createTransportMode)
    ..post('/locations', _createLocation)
    ..post('/routes', _createRouteMeta)
    ..post('/travel_logs', _createTravelLog)
    ..post('/safety_reports', _createSafetyReport)
    ..post('/incidents', _createIncident);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3000;
  final server = await io.serve(handler, '0.0.0.0', port);
  stdout.writeln('SafeRoute API running on http://${server.address.host}:${server.port}');
}

Response _health(Request request) {
  return Response.ok(
    jsonEncode({'status': 'ok'}),
    headers: _jsonHeaders,
  );
}

Future<Response> _register(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final name = (payload['name'] as String?)?.trim() ?? '';
    final email = (payload['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = payload['password'] as String? ?? '';

    if (name.isEmpty || email.isEmpty || password.length < 8) {
      return _badRequest('Provide a name, email, and password with at least 8 characters.');
    }

    final existing = await _db.execute(
      Sql.named('SELECT id FROM saferoute.users WHERE email = @email LIMIT 1'),
      parameters: {'email': email},
    );
    if (existing.isNotEmpty) {
      return _badRequest('An account with that email already exists.');
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
    final result = await _db.execute(
      Sql.named('INSERT INTO saferoute.users (name, email, password_hash) VALUES (@name, @email, @hash) RETURNING id'),
      parameters: {'name': name, 'email': email, 'hash': passwordHash},
    );

    final userId = result.first[0] as int;
    final session = _buildSession(
      user: {
        'id': userId,
        'name': name,
        'email': email,
      },
    );

    return Response.ok(jsonEncode(session), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Registration failed: $e');
  }
}

Future<Response> _login(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final email = (payload['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = payload['password'] as String? ?? '';

    if (email.isEmpty || password.isEmpty) {
      return _badRequest('Email and password are required.');
    }

    final rows = await _db.execute(
      Sql.named('SELECT id, name, email, password_hash FROM saferoute.users WHERE email = @email LIMIT 1'),
      parameters: {'email': email},
    );

    if (rows.isEmpty) {
      return _unauthorized('Invalid email or password.');
    }

    final row = rows.first;
    final userId = row[0] as int;
    final userName = row[1] as String;
    final userEmail = row[2] as String;
    final storedHash = row[3] as String;

    if (!BCrypt.checkpw(password, storedHash)) {
      return _unauthorized('Invalid email or password.');
    }

    final session = _buildSession(
      user: {
        'id': userId,
        'name': userName,
        'email': userEmail,
      },
    );

    return Response.ok(jsonEncode(session), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Login failed: $e');
  }
}

Future<Response> _recordRoute(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final userId = payload['userId'] as int?;
    final startLocationName = (payload['startLocationName'] as String?)?.trim() ?? '';
    final endLocationName = (payload['endLocationName'] as String?)?.trim() ?? '';
    final transportMode = (payload['transportMode'] as String?)?.trim() ?? '';
    final startLat = payload['startLatitude'] as double?;
    final startLng = payload['startLongitude'] as double?;
    final endLat = payload['endLatitude'] as double?;
    final endLng = payload['endLongitude'] as double?;
    final coordinates = payload['coordinates'] as List?;
    final distance = payload['distance'] as num?;
    final duration = payload['duration'] as int?;
    final rating = payload['rating'] as int?;
    final notes = payload['notes'] as String?;
    final startedAt = payload['startedAt'] as String?;
    final endedAt = payload['endedAt'] as String?;

    if (userId == null || startLocationName.isEmpty || endLocationName.isEmpty || transportMode.isEmpty || startLat == null || startLng == null || endLat == null || endLng == null || coordinates == null || distance == null || duration == null || startedAt == null || endedAt == null) {
      return _badRequest('Missing required fields: userId, startLocationName, endLocationName, transportMode, startLatitude, startLongitude, endLatitude, endLongitude, coordinates, distance, duration, startedAt, endedAt');
    }

    final coordinatesJson = jsonEncode(coordinates);
    final routeId = const Uuid().v4();

    await _db.execute(
      Sql.named('''INSERT INTO saferoute.recorded_routes 
         (id, user_id, start_location_name, end_location_name, transport_mode, start_latitude, start_longitude, end_latitude, end_longitude, coordinates, distance_meters, duration_seconds, rating, notes, started_at, ended_at)
         VALUES (@id, @userId, @startLocationName, @endLocationName, @transportMode, @startLat, @startLng, @endLat, @endLng, @coords, @distance, @duration, @rating, @notes, @startedAt, @endedAt)'''),
      parameters: {
        'id': routeId,
        'userId': userId,
        'startLocationName': startLocationName,
        'endLocationName': endLocationName,
        'transportMode': transportMode,
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
        'coords': coordinatesJson,
        'distance': distance,
        'duration': duration,
        'rating': rating,
        'notes': notes,
        'startedAt': startedAt,
        'endedAt': endedAt,
      },
    );

    return Response.ok(
      jsonEncode({'id': routeId, 'message': 'Route recorded successfully'}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return _serverError('Failed to record route: $e');
  }
}

Future<Response> _getUserRoutes(Request request, String userId) async {
  try {
    final userIdInt = int.tryParse(userId);
    if (userIdInt == null) {
      return _badRequest('Invalid user ID');
    }

    final rows = await _db.execute(
      Sql.named('''SELECT id, start_location_name, end_location_name, transport_mode, start_latitude, start_longitude, end_latitude, end_longitude, 
         coordinates, distance_meters, duration_seconds, rating, notes, started_at, ended_at, created_at
         FROM saferoute.recorded_routes 
         WHERE user_id = @userId 
         ORDER BY created_at DESC
         LIMIT 100'''),
      parameters: {'userId': userIdInt},
    );

    final routes = rows.map((row) => {
      'id': row[0],
      'startLocationName': row[1],
      'endLocationName': row[2],
      'transportMode': row[3],
      'startLatitude': row[4],
      'startLongitude': row[5],
      'endLatitude': row[6],
      'endLongitude': row[7],
      'coordinates': jsonDecode(row[8] as String),
      'distance': row[9],
      'duration': row[10],
      'rating': row[11],
      'notes': row[12],
      'startedAt': row[13].toString(),
      'endedAt': row[14].toString(),
      'createdAt': row[15].toString(),
    }).toList();

    return Response.ok(
      jsonEncode({'routes': routes}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return _serverError('Failed to fetch routes: $e');
  }
}

Future<Response> _createTransportMode(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final name = (payload['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return _badRequest('Transport mode name required');

    final existing = await _db.execute(
      Sql.named('SELECT id FROM saferoute.transport_modes WHERE name = @name LIMIT 1'),
      parameters: {'name': name},
    );
    if (existing.isNotEmpty) {
      return Response.ok(jsonEncode({'id': existing.first[0], 'name': name}), headers: _jsonHeaders);
    }

    final result = await _db.execute(
      Sql.named('INSERT INTO saferoute.transport_modes (name) VALUES (@name) RETURNING id'),
      parameters: {'name': name},
    );

    return Response.ok(jsonEncode({'id': result.first[0], 'name': name}), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Failed to create transport mode: $e');
  }
}

Future<Response> _createLocation(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final name = (payload['name'] as String?)?.trim();
    final lat = payload['latitude'] as double?;
    final lng = payload['longitude'] as double?;

    final result = await _db.execute(
      Sql.named('INSERT INTO saferoute.locations (name, latitude, longitude) VALUES (@name, @lat, @lng) RETURNING id'),
      parameters: {'name': name, 'lat': lat, 'lng': lng},
    );

    return Response.ok(jsonEncode({'id': result.first[0]}), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Failed to create location: $e');
  }
}

Future<Response> _createRouteMeta(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final userId = payload['userId'] as int?;
    final name = (payload['name'] as String?)?.trim() ?? '';
    final description = payload['description'] as String?;

    if (userId == null) return _badRequest('userId is required');

    final id = const Uuid().v4();
    await _db.execute(
      Sql.named('INSERT INTO saferoute.routes (id, user_id, name, description) VALUES (@id, @userId, @name, @desc)'),
      parameters: {'id': id, 'userId': userId, 'name': name, 'desc': description},
    );

    return Response.ok(jsonEncode({'id': id}), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Failed to create route metadata: $e');
  }
}

Future<Response> _createTravelLog(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final userId = payload['userId'] as int?;
    final routeId = payload['routeId'] as String?;
    final recordedRouteId = payload['recordedRouteId'] as String?;
    final transportModeId = payload['transportModeId'] as int?;
    final startedAt = payload['startedAt'] as String?;
    final endedAt = payload['endedAt'] as String?;
    final distance = payload['distance'] as num?;
    final duration = payload['duration'] as int?;
    final notes = payload['notes'] as String?;

    if (userId == null) return _badRequest('userId is required');

    final result = await _db.execute(
      Sql.named('''INSERT INTO saferoute.travel_logs (user_id, route_id, recorded_route_id, transport_mode_id, started_at, ended_at, distance_meters, duration_seconds, notes)
         VALUES (@userId, @routeId, @recordedRouteId, @transportModeId, @startedAt, @endedAt, @distance, @duration, @notes) RETURNING id'''),
      parameters: {
        'userId': userId,
        'routeId': routeId,
        'recordedRouteId': recordedRouteId,
        'transportModeId': transportModeId,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'distance': distance,
        'duration': duration,
        'notes': notes,
      },
    );

    return Response.ok(jsonEncode({'id': result.first[0]}), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Failed to create travel log: $e');
  }
}

Future<Response> _createSafetyReport(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final userId = payload['userId'] as int?;
    final routeId = payload['routeId'] as String?;
    final locationId = payload['locationId'] as int?;
    final description = payload['description'] as String?;
    final severity = payload['severity'] as int?;

    if (userId == null) return _badRequest('userId is required');

    final result = await _db.execute(
      Sql.named('INSERT INTO saferoute.safety_reports (user_id, route_id, location_id, description, severity) VALUES (@userId, @routeId, @locationId, @description, @severity) RETURNING id'),
      parameters: {
        'userId': userId,
        'routeId': routeId,
        'locationId': locationId,
        'description': description,
        'severity': severity,
      },
    );

    return Response.ok(jsonEncode({'id': result.first[0]}), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Failed to create safety report: $e');
  }
}

Future<Response> _createIncident(Request request) async {
  try {
    final payload = await _decodeRequest(request);
    final safetyReportId = payload['safetyReportId'] as int?;
    final incidentType = payload['incidentType'] as String?;
    final description = payload['description'] as String?;
    final locationId = payload['locationId'] as int?;
    final occurredAt = payload['occurredAt'] as String?;

    final result = await _db.execute(
      Sql.named('INSERT INTO saferoute.incidents (safety_report_id, incident_type, description, location_id, occurred_at) VALUES (@safetyReportId, @type, @desc, @locationId, @occurredAt) RETURNING id'),
      parameters: {
        'safetyReportId': safetyReportId,
        'type': incidentType,
        'desc': description,
        'locationId': locationId,
        'occurredAt': occurredAt,
      },
    );

    return Response.ok(jsonEncode({'id': result.first[0]}), headers: _jsonHeaders);
  } catch (e) {
    return _serverError('Failed to create incident: $e');
  }
}

Future<void> _ensureSchema() async {
  await _db.execute('''
    CREATE SCHEMA IF NOT EXISTS saferoute
  ''');

  await _db.execute('''
    CREATE EXTENSION IF NOT EXISTS pgcrypto
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS saferoute.users (
      id SERIAL PRIMARY KEY,
      name VARCHAR(120) NOT NULL,
      email VARCHAR(180) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _db.execute('''
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
  ''');

  await _db.execute('''
    CREATE INDEX IF NOT EXISTS idx_recorded_routes_user_id ON saferoute.recorded_routes(user_id)
  ''');

  await _db.execute('''
    CREATE INDEX IF NOT EXISTS idx_recorded_routes_created_at ON saferoute.recorded_routes(created_at)
  ''');

  await _db.execute('''
    ALTER TABLE saferoute.recorded_routes
      ADD COLUMN IF NOT EXISTS start_location_name TEXT
  ''');

  await _db.execute('''
    ALTER TABLE saferoute.recorded_routes
      ADD COLUMN IF NOT EXISTS end_location_name TEXT
  ''');

  await _db.execute('''
    ALTER TABLE saferoute.recorded_routes
      ADD COLUMN IF NOT EXISTS transport_mode TEXT NOT NULL DEFAULT 'walking'
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS saferoute.transport_modes (
      id SERIAL PRIMARY KEY,
      name VARCHAR(80) NOT NULL UNIQUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS saferoute.locations (
      id SERIAL PRIMARY KEY,
      name TEXT,
      latitude DECIMAL(10,8),
      longitude DECIMAL(11,8),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS saferoute.routes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
      name TEXT,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _db.execute('''
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
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS saferoute.safety_reports (
      id SERIAL PRIMARY KEY,
      user_id INT NOT NULL REFERENCES saferoute.users(id) ON DELETE CASCADE,
      route_id UUID REFERENCES saferoute.routes(id) ON DELETE SET NULL,
      location_id INT REFERENCES saferoute.locations(id) ON DELETE SET NULL,
      description TEXT,
      severity INT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _db.execute('''
    CREATE TABLE IF NOT EXISTS saferoute.incidents (
      id SERIAL PRIMARY KEY,
      safety_report_id INT REFERENCES saferoute.safety_reports(id) ON DELETE CASCADE,
      incident_type TEXT,
      description TEXT,
      location_id INT REFERENCES saferoute.locations(id) ON DELETE SET NULL,
      occurred_at TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _db.execute('''
    CREATE INDEX IF NOT EXISTS idx_travel_logs_user_id ON saferoute.travel_logs(user_id)
  ''');

  await _db.execute('''
    CREATE INDEX IF NOT EXISTS idx_safety_reports_user_id ON saferoute.safety_reports(user_id)
  ''');
}

Future<Map<String, dynamic>> _decodeRequest(Request request) async {
  final body = await request.readAsString();
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }

  return jsonDecode(body) as Map<String, dynamic>;
}

Map<String, dynamic> _buildSession({required Map<String, dynamic> user}) {
  return {
    'token': const Uuid().v4(),
    'user': user,
  };
}

Response _badRequest(String message) {
  return Response(
    400,
    body: jsonEncode({'message': message}),
    headers: _jsonHeaders,
  );
}

Response _unauthorized(String message) {
  return Response(
    401,
    body: jsonEncode({'message': message}),
    headers: _jsonHeaders,
  );
}

Response _serverError(String message) {
  return Response(
    500,
    body: jsonEncode({'message': message}),
    headers: _jsonHeaders,
  );
}

const _jsonHeaders = <String, String>{
  HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
};