import 'package:flutter/material.dart';

import '../models/safe_route.dart';

const transportInsights = <TransportInsight>[
  TransportInsight(
    label: 'Women facing transport poverty',
    value: '1 in 3',
    note: 'Surveyed commuters report unsafe or unaffordable travel on at least one weekly trip.',
    icon: Icons.pregnant_woman_outlined,
    accent: Color(0xFF0E7C7B),
  ),
  TransportInsight(
    label: 'Low-lit stops',
    value: '18',
    note: 'Stops with limited lighting and no shelter are flagged as higher-risk nodes.',
    icon: Icons.lightbulb_outline,
    accent: Color(0xFFC96B5C),
  ),
  TransportInsight(
    label: 'Recommended safe corridors',
    value: '6',
    note: 'Routes verified by local riders, predictable headways, and active street frontage.',
    icon: Icons.route_outlined,
    accent: Color(0xFF274060),
  ),
];

const safeRouteRecommendations = <SafeRouteRecommendation>[
  SafeRouteRecommendation(
    title: 'Central Station to Riverside Homes',
    origin: 'Central Station',
    destination: 'Riverside Homes',
    period: CommutePeriod.evening,
    duration: '28 min',
    walkMinutes: 9,
    transfers: 1,
    safetyScore: 91,
    summary: 'Uses the main boulevard, a staffed interchange, and the busiest well-lit stop sequence.',
    highlights: [
      'Street lighting stays consistent until arrival.',
      'Local spotters report frequent passenger flow.',
      'One short transfer keeps wait time low.',
    ],
    cautions: [
      'Avoid the side lane near the market after 8:30 PM.',
    ],
    communityVerified: true,
  ),
  SafeRouteRecommendation(
    title: 'Market District to North College',
    origin: 'Market District',
    destination: 'North College',
    period: CommutePeriod.morning,
    duration: '24 min',
    walkMinutes: 6,
    transfers: 0,
    safetyScore: 87,
    summary: 'Fastest option for early classes with a sheltered stop and a direct bus corridor.',
    highlights: [
      'Direct service with no transfer.',
      'Sheltered stop and active kiosk along the route.',
      'High pedestrian visibility during commute hours.',
    ],
    cautions: [
      'Morning crowding can affect boarding near the market plaza.',
    ],
    communityVerified: true,
  ),
  SafeRouteRecommendation(
    title: 'East Clinic to Home Support Hub',
    origin: 'East Clinic',
    destination: 'Home Support Hub',
    period: CommutePeriod.afternoon,
    duration: '18 min',
    walkMinutes: 4,
    transfers: 0,
    safetyScore: 84,
    summary: 'Short hop using the hospital-facing stop with nearby security staff and clear sightlines.',
    highlights: [
      'Accessible boarding and curb ramps.',
      'Regular service during daylight hours.',
      'Low walk time for passengers with care duties.',
    ],
    cautions: [
      'Service gaps widen after 4:30 PM.',
    ],
    communityVerified: true,
  ),
  SafeRouteRecommendation(
    title: 'Harbor Workshop to West Market',
    origin: 'Harbor Workshop',
    destination: 'West Market',
    period: CommutePeriod.night,
    duration: '31 min',
    walkMinutes: 7,
    transfers: 1,
    safetyScore: 73,
    summary: 'Fallback route for late shifts that stays on the broader arterial road and avoids isolated cut-throughs.',
    highlights: [
      'Primary road keeps rider visibility high.',
      'Emergency stop is within a short walk from the destination.',
      'Late-night frequency is better than the alternative routes.',
    ],
    cautions: [
      'Night patrol coverage drops after 10:00 PM.',
      'Use only when the main corridor service is confirmed.',
    ],
    communityVerified: false,
  ),
];

const communityActions = <CommunityAction>[
  CommunityAction(
    title: 'Report an unsafe stop',
    subtitle: 'Flag poor lighting, harassment, or broken shelter infrastructure.',
    icon: Icons.report_gmailerrorred_outlined,
    tint: Color(0xFFC96B5C),
  ),
  CommunityAction(
    title: 'Share a live route plan',
    subtitle: 'Send your itinerary to a trusted contact before you travel.',
    icon: Icons.share_location_outlined,
    tint: Color(0xFF0E7C7B),
  ),
  CommunityAction(
    title: 'Identify safe pickup points',
    subtitle: 'Save high-visibility stops used by riders and local vendors.',
    icon: Icons.place_outlined,
    tint: Color(0xFF274060),
  ),
  CommunityAction(
    title: 'Request a women-led shuttle',
    subtitle: 'Log demand for shuttle pilots and escorted last-mile trips.',
    icon: Icons.directions_bus_filled_outlined,
    tint: Color(0xFF7A4E2D),
  ),
];

const emergencyContacts = <EmergencyContact>[
  EmergencyContact(
    label: 'Emergency response',
    number: '112',
    note: 'Immediate support for urgent safety incidents.',
    icon: Icons.local_police_outlined,
  ),
  EmergencyContact(
    label: 'Women transport desk',
    number: '+1 555 0142',
    note: 'Route assistance, reporting, and local referral support.',
    icon: Icons.support_agent_outlined,
  ),
  EmergencyContact(
    label: 'Trusted contact',
    number: '+1 555 0188',
    note: 'A personal check-in for departure and arrival confirmation.',
    icon: Icons.shield_outlined,
  ),
];