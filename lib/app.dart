import 'package:flutter/material.dart';

import 'auth/auth_models.dart';
import 'screens/auth_screen.dart';
import 'services/backend_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

class SafeRouteApp extends StatefulWidget {
  const SafeRouteApp({super.key});

  @override
  State<SafeRouteApp> createState() => _SafeRouteAppState();
}

class _SafeRouteAppState extends State<SafeRouteApp> {
  AuthSession? _session;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final result = await Future.wait<dynamic>([
      BackendService.initialize(),
      Future<void>.delayed(const Duration(seconds: 2)),
      AuthService.instance.getStoredSession(),
    ]);

    if (!mounted) return;
    setState(() {
      _session = result[1] as AuthSession?;
      _isCheckingSession = false;
    });
  }

  void _onAuthenticated(AuthSession session) {
    setState(() {
      _session = session;
    });
  }

  Future<void> _onSignOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    setState(() {
      _session = null;
    });
  }

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
      home: _isCheckingSession
          ? const SplashScreen()
          : (_session == null
              ? AuthScreen(onAuthenticated: _onAuthenticated)
              : HomeScreen(
                  user: _session!.user,
                  onSignOut: _onSignOut,
                )),
    );
  }
}