import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

late PostgreSQLConnection _db;

Future<void> main() async {
  // Initialize database connection
  _db = PostgreSQLConnection(
    Platform.environment['DB_HOST'] ?? 'localhost',
    int.tryParse(Platform.environment['DB_PORT'] ?? '') ?? 5432,
    Platform.environment['DB_NAME'] ?? 'saferoute',
    username: Platform.environment['DB_USER'] ?? 'postgres',
    password: Platform.environment['DB_PASSWORD'] ?? '',
  );

  await _db.open();
  await _ensureSchema();

  final router = Router()
    ..get('/health', _health)
    ..post('/auth/register', _register)
    ..post('/auth/login', _login)
    ..post('/routes/record', _recordRoute)
    ..get('/routes/user/<userId>', _getUserRoutes);

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

    final existing = await _db.query(
      'SELECT id FROM saferoute.users WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );
    if (existing.isNotEmpty) {
      return _badRequest('An account with that email already exists.');
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
    final result = await _db.query(
      'INSERT INTO saferoute.users (name, email, password_hash) VALUES (@name, @email, @hash) RETURNING id',
      substitutionValues: {'name': name, 'email': email, 'hash': passwordHash},
    );

    final userId = result.first.first as int;
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

    final rows = await _db.query(
      'SELECT id, name, email, password_hash FROM saferoute.users WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
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

    await _db.query(
      '''INSERT INTO saferoute.recorded_routes 
         (id, user_id, start_location_name, end_location_name, transport_mode, start_latitude, start_longitude, end_latitude, end_longitude, coordinates, distance_meters, duration_seconds, rating, notes, started_at, ended_at)
         VALUES (@id, @userId, @startLocationName, @endLocationName, @transportMode, @startLat, @startLng, @endLat, @endLng, @coords, @distance, @duration, @rating, @notes, @startedAt, @endedAt)''',
      substitutionValues: {
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

    final rows = await _db.query(
      '''SELECT id, start_location_name, end_location_name, transport_mode, start_latitude, start_longitude, end_latitude, end_longitude, 
         coordinates, distance_meters, duration_seconds, rating, notes, started_at, ended_at, created_at
         FROM saferoute.recorded_routes 
         WHERE user_id = @userId 
         ORDER BY created_at DESC
         LIMIT 100''',
      substitutionValues: {'userId': userIdInt},
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

Future<void> _ensureSchema() async {
  await _db.execute('''
    CREATE SCHEMA IF NOT EXISTS saferoute
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