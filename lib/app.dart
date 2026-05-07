import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class SafeRouteApp extends StatelessWidget {
  const SafeRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7C7B),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeRoute',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme.copyWith(
          primary: const Color(0xFF0E7C7B),
          secondary: const Color(0xFFC96B5C),
          tertiary: const Color(0xFF274060),
          surface: const Color(0xFFF7F2EA),
          surfaceContainerHighest: const Color(0xFFE8DED0),
          error: const Color(0xFFB83B5E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F2EA),
      ),
      home: const HomeScreen(),
    );
  }
}