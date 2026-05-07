import 'package:flutter/material.dart';

enum CommutePeriod { morning, afternoon, evening, night }

extension CommutePeriodX on CommutePeriod {
  String get label => switch (this) {
        CommutePeriod.morning => 'Morning',
        CommutePeriod.afternoon => 'Afternoon',
        CommutePeriod.evening => 'Evening',
        CommutePeriod.night => 'Night',
      };

  String get window => switch (this) {
        CommutePeriod.morning => '6:00 AM - 10:00 AM',
        CommutePeriod.afternoon => '10:00 AM - 4:00 PM',
        CommutePeriod.evening => '4:00 PM - 9:00 PM',
        CommutePeriod.night => '9:00 PM - 6:00 AM',
      };

  IconData get icon => switch (this) {
        CommutePeriod.morning => Icons.wb_sunny_outlined,
        CommutePeriod.afternoon => Icons.wb_twilight_outlined,
        CommutePeriod.evening => Icons.nightlight_round,
        CommutePeriod.night => Icons.nights_stay_outlined,
      };
}

class TransportInsight {
  const TransportInsight({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color accent;
}

class SafeRouteRecommendation {
  const SafeRouteRecommendation({
    required this.title,
    required this.origin,
    required this.destination,
    required this.period,
    required this.duration,
    required this.walkMinutes,
    required this.transfers,
    required this.safetyScore,
    required this.summary,
    required this.highlights,
    required this.cautions,
    required this.communityVerified,
  });

  final String title;
  final String origin;
  final String destination;
  final CommutePeriod period;
  final String duration;
  final int walkMinutes;
  final int transfers;
  final int safetyScore;
  final String summary;
  final List<String> highlights;
  final List<String> cautions;
  final bool communityVerified;
}

class CommunityAction {
  const CommunityAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
}

class EmergencyContact {
  const EmergencyContact({
    required this.label,
    required this.number,
    required this.note,
    required this.icon,
  });

  final String label;
  final String number;
  final String note;
  final IconData icon;
}