import 'package:latlong2/latlong.dart';

class RecordedRoute {
  RecordedRoute({
    this.id,
    required this.startLocationName,
    required this.endLocationName,
    required this.transportMode,
    required this.startPoint,
    required this.endPoint,
    required this.coordinates,
    required this.startTime,
    required this.endTime,
    required this.distance,
    this.rating,
    this.notes,
    this.fareCost,
    this.waitingTimeMinutes,
    this.transferCount,
    this.safetyAssessment = const <String, int>{},
    this.consentAccepted = false,
  });

  final String? id;
  final String startLocationName;
  final String endLocationName;
  final String transportMode;
  final LatLng startPoint;
  final LatLng endPoint;
  final List<LatLng> coordinates;
  final DateTime startTime;
  final DateTime endTime;
  final double distance; // in meters
  final int? rating; // 1-5 stars
  final String? notes;
  final double? fareCost;
  final int? waitingTimeMinutes;
  final int? transferCount;
  final Map<String, int> safetyAssessment;
  final bool consentAccepted;

  Duration get duration => endTime.difference(startTime);

  String get durationStr {
    final mins = duration.inMinutes;
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    if (hours == 0) return '$mins min';
    return '$hours h $remainingMins min';
  }

  String get distanceStr {
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startLocationName': startLocationName,
    'endLocationName': endLocationName,
    'transportMode': transportMode,
    'startPoint': {'lat': startPoint.latitude, 'lng': startPoint.longitude},
    'endPoint': {'lat': endPoint.latitude, 'lng': endPoint.longitude},
    'coordinates': coordinates
        .map((c) => {'lat': c.latitude, 'lng': c.longitude})
        .toList(),
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'distance': distance,
    'rating': rating,
    'notes': notes,
    'fareCost': fareCost,
    'waitingTimeMinutes': waitingTimeMinutes,
    'transferCount': transferCount,
    'safetyAssessment': safetyAssessment,
    'consentAccepted': consentAccepted,
  };

  factory RecordedRoute.fromJson(Map<String, dynamic> json) {
    final startPointJson = json['startPoint'] as Map?;
    final endPointJson = json['endPoint'] as Map?;
    final coordinatesJson =
        ((json['coordinates'] as List?)?.cast<Map>() ?? const <Map>[]);
    final startPoint = startPointJson == null
        ? LatLng(
            _numValue(json['startLatitude'] ?? json['start_latitude']),
            _numValue(json['startLongitude'] ?? json['start_longitude']),
          )
        : LatLng(
            _numValue(startPointJson['lat']),
            _numValue(startPointJson['lng']),
          );
    final endPoint = endPointJson == null
        ? LatLng(
            _numValue(json['endLatitude'] ?? json['end_latitude']),
            _numValue(json['endLongitude'] ?? json['end_longitude']),
          )
        : LatLng(
            _numValue(endPointJson['lat']),
            _numValue(endPointJson['lng']),
          );
    final coordinates = coordinatesJson
        .map((c) => LatLng(_numValue(c['lat']), _numValue(c['lng'])))
        .toList();

    return RecordedRoute(
      id: json['id']?.toString(),
      startLocationName:
          json['startLocationName'] as String? ??
          json['start_location_name'] as String? ??
          '',
      endLocationName:
          json['endLocationName'] as String? ??
          json['end_location_name'] as String? ??
          '',
      transportMode:
          json['transportMode'] as String? ??
          json['transport_mode'] as String? ??
          'walking',
      startPoint: startPoint,
      endPoint: endPoint,
      coordinates: coordinates.isEmpty
          ? <LatLng>[startPoint, endPoint]
          : coordinates,
      startTime: DateTime.parse(
        (json['startTime'] ?? json['startedAt'] ?? json['started_at'])
            as String,
      ),
      endTime: DateTime.parse(
        (json['endTime'] ?? json['endedAt'] ?? json['ended_at']) as String,
      ),
      distance: _numValue(json['distance']),
      rating: (json['rating'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      fareCost: (json['fareCost'] as num?)?.toDouble(),
      waitingTimeMinutes: (json['waitingTimeMinutes'] as num?)?.toInt(),
      transferCount: (json['transferCount'] as num?)?.toInt(),
      safetyAssessment:
          ((json['safetyAssessment'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{})
              .map((key, value) => MapEntry(key, (value as num).toInt())),
      consentAccepted: json['consentAccepted'] as bool? ?? false,
    );
  }

  static double _numValue(Object? value) => (value as num?)?.toDouble() ?? 0;
}
