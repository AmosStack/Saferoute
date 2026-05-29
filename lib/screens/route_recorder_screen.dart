import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../data/mock_data.dart';
import '../services/backend_service.dart';
import '../services/route_recorder_service.dart';
import '../services/user_settings_service.dart';

class RouteRecorderScreen extends StatefulWidget {
  const RouteRecorderScreen({
    super.key,
    required this.startPoint,
    required this.destination,
    required this.startLocationName,
    required this.endLocationName,
    required this.transportMode,
    this.userId,
  });

  final ll.LatLng startPoint;
  final ll.LatLng destination;
  final String startLocationName;
  final String endLocationName;
  final String transportMode;
  final int? userId;

  @override
  State<RouteRecorderScreen> createState() => _RouteRecorderScreenState();
}

class _RouteRecorderScreenState extends State<RouteRecorderScreen> {
  late final RouteRecorderService _recorderService;
  gmaps.GoogleMapController? _mapController;
  bool _showUserLocation = false;
  bool _hasArrivedNotified = false;
  bool _isArrivalDialogOpen = false;
  bool _isIncidentDialogOpen = false;
  int _arrivalHitCount = 0;
  int _selectedRating = 0;
  String? _currentLocationName;
  ll.LatLng? _currentReportedPoint;
  String? _currentReportedLocationName;
  ll.LatLng? _lastLocationNameLookupPoint;
  ll.LatLng? _lastFollowedPoint;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _incidentDescriptionController = TextEditingController();
  String _incidentType = 'Unsafe road condition';

  static const String _sosIncidentType = 'SOS';

  static const List<String> _incidentTypes = <String>[
    'Unsafe road condition',
    'Harassment',
    'Poor lighting',
    'Traffic hazard',
    'Vehicle issue',
    'Other',
  ];

  Future<List<_SosRecipient>> _loadSosRecipients() async {
    final trustedContacts = await UserSettingsService.loadTrustedContacts();
    if (trustedContacts.isNotEmpty) {
      return trustedContacts
          .map(
            (contact) => _SosRecipient(
              name: contact.name,
              phone: contact.phone,
              note: contact.relationship.isNotEmpty ? contact.relationship : 'Trusted contact',
            ),
          )
          .toList(growable: false);
    }

    return emergencyContacts
        .map(
          (contact) => _SosRecipient(
            name: contact.label,
            phone: contact.number,
            note: contact.note,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _launchSms(_SosRecipient recipient, String message) async {
    final uri = Uri.parse('sms:${recipient.phone}?body=${Uri.encodeComponent(message)}');
    if (!await canLaunchUrl(uri)) {
      throw Exception('No messaging app can handle this request.');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendSosToRecipient(_SosRecipient recipient) async {
    final currentPoint = _recorderService.currentLatLng ?? widget.startPoint;
    final locationName = _currentLocationName ?? await _reverseGeocode(currentPoint) ?? 'Unknown location';
    final message = [
      'SOS from SafeRoute.',
      'I need help and I am traveling now.',
      'Location: $locationName',
      'Map: https://maps.google.com/?q=${currentPoint.latitude},${currentPoint.longitude}',
    ].join(' ');

    await _launchSms(recipient, message);

    if (widget.userId != null) {
      try {
        final locationId = await _createLocationRecord(currentPoint, preferredName: locationName);
        await BackendService.createIncident(
          incidentType: _sosIncidentType,
          description: 'SOS sent to ${recipient.name}. $message',
          locationId: locationId,
          occurredAt: DateTime.now(),
        );
      } catch (e) {
        debugPrint('Failed to log SOS incident: $e');
      }
    }
  }

  Future<void> _showSosSheet() async {
    final recipients = await _loadSosRecipients();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;
        final surfaceColor = isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
        final titleColor = isDark ? Colors.white : Colors.black;
        final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.78) : Colors.black.withValues(alpha: 0.7);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send SOS', style: theme.textTheme.titleLarge?.copyWith(color: titleColor)),
                const SizedBox(height: 8),
                Text(
                  'Choose a trusted person or emergency contact to receive your location message.',
                  style: TextStyle(color: subtitleColor),
                ),
                const SizedBox(height: 12),
                for (final recipient in recipients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0E7C7B),
                        child: Icon(Icons.message, color: Colors.white),
                      ),
                      title: Text(recipient.name, style: TextStyle(color: titleColor)),
                      subtitle: Text(
                        '${recipient.phone}\n${recipient.note}',
                        style: TextStyle(color: subtitleColor),
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        try {
                          await _sendSosToRecipient(recipient);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('SOS prepared for ${recipient.name}')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not send SOS: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  gmaps.LatLng _toGoogleLatLng(ll.LatLng point) {
    return gmaps.LatLng(point.latitude, point.longitude);
  }

  double _distanceMeters(ll.LatLng a, ll.LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180.0);
    final dLon = (b.longitude - a.longitude) * (math.pi / 180.0);
    final lat1 = a.latitude * (math.pi / 180.0);
    final lat2 = b.latitude * (math.pi / 180.0);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final h = sinLat * sinLat + (sinLon * sinLon) * (math.cos(lat1) * math.cos(lat2));
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  Future<void> _moveCamera(ll.LatLng target, {double zoom = 16.0}) async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: _toGoogleLatLng(target),
          zoom: zoom,
        ),
      ),
    );
  }

  Future<String?> _reverseGeocode(ll.LatLng point) async {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
      queryParameters: {
        'format': 'json',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
      },
    );

    try {
      final resp = await http.get(uri, headers: {'User-Agent': 'SafeRouteDev/0.1'});
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final displayName = data['display_name']?.toString();
      if (displayName == null || displayName.trim().isEmpty) return null;
      return displayName.split(',').first.trim();
    } catch (_) {
      return null;
    }
  }

  Future<int?> _createLocationRecord(
    ll.LatLng point, {
    String? preferredName,
  }) async {
    final resolvedName = (preferredName ?? await _reverseGeocode(point) ?? 'Reported location').trim();
    try {
      return await BackendService.createLocation(
        name: resolvedName.isEmpty ? 'Reported location' : resolvedName,
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } catch (e) {
      debugPrint('Failed to create location record: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    await _recorderService.startRecording(widget.startPoint);
    if (!mounted) return;
    setState(() {
      _showUserLocation = true;
    });
    await _moveCamera(widget.startPoint, zoom: 16.0);
  }

  Future<void> _cancelRoute() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel route?'),
          content: const Text('This will discard the current recording and return you to the previous screen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep recording'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    if (shouldDiscard != true) return;

    await _recorderService.cancelRecording();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveRoute({ll.LatLng? locationPoint, String? locationName}) async {
    final route = await _recorderService.stopRecording(
      widget.destination,
      startLocationName: widget.startLocationName,
      endLocationName: widget.endLocationName,
      transportMode: widget.transportMode,
      rating: _selectedRating,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    if (widget.userId != null) {
      final saved = await BackendService.saveRoute(
        userId: widget.userId!,
        route: route,
      );

      if (saved) {
        try {
          final transportModeId = await BackendService.createTransportMode(widget.transportMode);
          int? locationId;
          final reportPoint = locationPoint ?? _currentReportedPoint ?? _recorderService.currentLatLng ?? widget.destination;
          final reportName = locationName ?? _currentReportedLocationName ?? _currentLocationName ?? widget.endLocationName;
          await BackendService.createTravelLog(
            userId: widget.userId!,
            recordedRouteId: route.id,
            transportModeId: transportModeId,
            startedAt: route.startTime,
            endedAt: route.endTime,
            distanceMeters: route.distance,
            durationSeconds: route.duration.inSeconds,
            notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          );

          if (_notesController.text.isNotEmpty && _selectedRating != 0) {
            final notes = _notesController.text.toLowerCase();
            if (notes.contains('unsafe') ||
                notes.contains('danger') ||
                notes.contains('problem') ||
                _selectedRating <= 2) {
              locationId ??= await _createLocationRecord(reportPoint, preferredName: reportName);
              await BackendService.createSafetyReport(
                userId: widget.userId!,
                routeId: route.id,
                locationId: locationId,
                description: _notesController.text,
                severity: 5 - _selectedRating,
              );
            }
          }
        } catch (e) {
          debugPrint('Error saving travel log/safety report: $e');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save route to server')),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop({'route': route});
    }
  }

  Future<void> _showArrivalForm() async {
    if (_isArrivalDialogOpen || !mounted) return;
    _isArrivalDialogOpen = true;

    final currentPoint = _recorderService.currentLatLng ?? widget.destination;
    final currentName = await _reverseGeocode(currentPoint);
    if (!mounted) return;
    setState(() {
      _currentLocationName = currentName;
      _currentReportedPoint = currentPoint;
      _currentReportedLocationName = currentName;
    });

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arrival detected',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.endLocationName} reached',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _currentLocationName == null
                          ? 'Current location: ${currentPoint.latitude.toStringAsFixed(5)}, ${currentPoint.longitude.toStringAsFixed(5)}'
                          : 'Current location: $_currentLocationName',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How safe was the route? Describe any unsafe areas or route issues.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => IconButton(
                          icon: Icon(
                            Icons.star,
                            color: i < _selectedRating ? Colors.amber : Colors.grey,
                            size: 32,
                          ),
                          onPressed: () {
                            dialogSetState(() {
                              _selectedRating = i + 1;
                            });
                            setState(() {
                              _selectedRating = i + 1;
                            });
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Describe safety concerns, route quality, or observations',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _isArrivalDialogOpen = false;
                              _arrivalHitCount = 0;
                              _hasArrivedNotified = false;
                            },
                            child: const Text('Continue tracking'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _saveRoute(
                                locationPoint: currentPoint,
                                locationName: currentName,
                              );
                            },
                            child: const Text('Save route'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _isArrivalDialogOpen = false;
  }

  Future<void> _showIncidentDialog() async {
    if (_isIncidentDialogOpen || !mounted) return;
    _isIncidentDialogOpen = true;

    final currentPoint = _recorderService.currentLatLng ?? widget.startPoint;
    final locationName = await _reverseGeocode(currentPoint);
    if (!mounted) return;

    final descriptionController = _incidentDescriptionController;
    descriptionController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report incident',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locationName == null
                        ? 'Current position: ${currentPoint.latitude.toStringAsFixed(5)}, ${currentPoint.longitude.toStringAsFixed(5)}'
                        : 'Current location: $locationName',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _incidentType,
                    items: _incidentTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      sheetSetState(() {
                        _incidentType = value;
                      });
                      setState(() {
                        _incidentType = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Incident type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Describe what happened and why the location felt unsafe',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final currentDescription = descriptionController.text.trim();
                            if (currentDescription.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please describe the incident')),
                              );
                              return;
                            }

                            Navigator.of(sheetContext).pop();
                            try {
                              final locationId = await _createLocationRecord(
                                currentPoint,
                                preferredName: locationName,
                              );
                              await BackendService.createIncident(
                                incidentType: _incidentType,
                                description: [
                                  'Location: ${locationName ?? '${currentPoint.latitude.toStringAsFixed(5)}, ${currentPoint.longitude.toStringAsFixed(5)}'}',
                                  currentDescription,
                                ].join('\n'),
                                locationId: locationId,
                                occurredAt: DateTime.now(),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Incident report sent')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to send incident report: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    _isIncidentDialogOpen = false;
  }

  void _onLocationUpdate() {
    if (!mounted) return;

    final currentPoint = _recorderService.currentLatLng;
    if (currentPoint != null && !_hasArrivedNotified) {
      if (_lastFollowedPoint == null || _distanceMeters(_lastFollowedPoint!, currentPoint) > 8) {
        _lastFollowedPoint = currentPoint;
        _moveCamera(currentPoint, zoom: 17.0);
      }

      if (_lastLocationNameLookupPoint == null || _distanceMeters(_lastLocationNameLookupPoint!, currentPoint) > 60) {
        _lastLocationNameLookupPoint = currentPoint;
        _reverseGeocode(currentPoint).then((name) {
          if (!mounted || name == null || name.isEmpty) return;
          setState(() {
            _currentLocationName = name;
          });
        });
      }
    }

    if (currentPoint != null) {
      final nearDestination = _recorderService.isNearDestination(widget.destination, thresholdMeters: 45);
      if (nearDestination) {
        _arrivalHitCount += 1;
      } else {
        _arrivalHitCount = 0;
      }

      if (!_hasArrivedNotified && _arrivalHitCount >= 2) {
        _hasArrivedNotified = true;
        _showArrivalForm();
      }
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _recorderService = RouteRecorderService();
    _recorderService.addListener(_onLocationUpdate);
    _startRecording();
  }

  @override
  void dispose() {
    _recorderService.removeListener(_onLocationUpdate);
    _recorderService.dispose();
    _notesController.dispose();
    _incidentDescriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark ? Colors.white.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.65);
    final coords = _recorderService.coordinates;
    final currentPoint = _recorderService.currentLatLng;
    final isRecording = _recorderService.isRecording;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRecording ? 'Recording route' : 'Route paused'),
        actions: [
          TextButton.icon(
            onPressed: _cancelRoute,
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          gmaps.GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _moveCamera(widget.startPoint, zoom: 16.0);
            },
            initialCameraPosition: gmaps.CameraPosition(
              target: _toGoogleLatLng(widget.startPoint),
              zoom: 16.0,
            ),
            myLocationEnabled: _showUserLocation,
            myLocationButtonEnabled: _showUserLocation,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              gmaps.Marker(
                markerId: const gmaps.MarkerId('start'),
                position: _toGoogleLatLng(widget.startPoint),
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
              ),
              gmaps.Marker(
                markerId: const gmaps.MarkerId('destination'),
                position: _toGoogleLatLng(widget.destination),
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
              ),
              if (currentPoint != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('live_location'),
                  position: _toGoogleLatLng(currentPoint),
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
                ),
            },
            polylines: {
              if (coords.length > 1)
                gmaps.Polyline(
                  polylineId: const gmaps.PolylineId('recorded_route'),
                  points: coords.map(_toGoogleLatLng).toList(),
                  width: 4,
                  color: Colors.blueAccent,
                ),
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.startLocationName} → ${widget.endLocationName}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mode: ${widget.transportMode}',
                      style: TextStyle(fontSize: 12, color: mutedTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentLocationName == null
                          ? 'Live location tracking active'
                          : 'Live: $_currentLocationName',
                      style: TextStyle(fontSize: 12, color: mutedTextColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Distance', style: TextStyle(fontSize: 12, color: mutedTextColor)),
                            Text(
                              _recorderService.totalDistance < 1000
                                  ? '${_recorderService.totalDistance.toStringAsFixed(0)} m'
                                  : '${(_recorderService.totalDistance / 1000).toStringAsFixed(2)} km',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Points Recorded', style: TextStyle(fontSize: 12, color: mutedTextColor)),
                            Text(
                              '${coords.length}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_hasArrivedNotified)
            Positioned(
              bottom: 24,
              left: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    onPressed: _showSosSheet,
                    backgroundColor: Colors.red.shade700,
                    icon: const Icon(Icons.sos),
                    label: const Text('SOS'),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    onPressed: _showIncidentDialog,
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.report_problem),
                    label: const Text('Report issue'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SosRecipient {
  const _SosRecipient({required this.name, required this.phone, required this.note});

  final String name;
  final String phone;
  final String note;
}
