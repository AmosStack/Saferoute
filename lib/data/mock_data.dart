import 'package:latlong2/latlong.dart' as ll;

/// Mock emergency contact list used as a fallback when trusted contacts
/// have not been configured.
class MockEmergencyContact {
  const MockEmergencyContact({
    required this.label,
    required this.number,
    required this.note,
  });

  final String label;
  final String number;
  final String note;
}

/// Example emergency contacts.
///
/// Note: This file exists to satisfy imports from UI code.
/// Replace with real backend or user settings integration as needed.
const List<MockEmergencyContact> emergencyContacts = <MockEmergencyContact>[
  MockEmergencyContact(
    label: 'Emergency Contact',
    number: '+255700000001',
    note: 'Add your trusted person here',
  ),
  MockEmergencyContact(
    label: 'Another Contact',
    number: '+255700000002',
    note: 'Secondary fallback contact',
  ),
];

// Convenience mock point (not currently used but kept for parity with
// potential future mock data usage).
const ll.LatLng mockLocationPoint = ll.LatLng(-1.292066, 36.821946);

