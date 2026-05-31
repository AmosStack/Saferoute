import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_models.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/user_settings_service.dart';

const Color _brandGreen = Color(0xFF0E7C7B);
const Color _brandGreenDark = Color(0xFF0A5F5F);
const Color _brandMint = Color(0xFFE8F4F2);
const Color _brandSurface = Color(0xFFF5F7F6);

class SafeRouteApp extends StatefulWidget {
  const SafeRouteApp({super.key});

  @override
  State<SafeRouteApp> createState() => _SafeRouteAppState();
}

class _SafeRouteAppState extends State<SafeRouteApp> {
  AuthSession? _session;
  bool _isCheckingSession = true;
  String _localeCode = 'en';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode _themeModeFromCode(String code) {
    return switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeModeCode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final result = await Future.wait<dynamic>([
        Future<void>.delayed(const Duration(seconds: 2)),
        AuthService.instance.getStoredSession(),
        UserSettingsService.loadLocaleCode(),
        UserSettingsService.loadThemeModeCode(),
      ]);

      if (!mounted) return;
      setState(() {
        _session = result[1] as AuthSession?;
        _localeCode = result[2] as String? ?? 'en';
        _themeMode = _themeModeFromCode(result[3] as String? ?? 'system');
        _isCheckingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _localeCode = 'en';
        _themeMode = ThemeMode.system;
        _isCheckingSession = false;
      });
    }
  }

  Future<void> _onLocaleChanged(String localeCode) async {
    await UserSettingsService.setLocaleCode(localeCode);
    if (!mounted) return;
    setState(() {
      _localeCode = localeCode;
    });
  }

  Future<void> _onThemeModeChanged(ThemeMode mode) async {
    await UserSettingsService.setThemeModeCode(_themeModeCode(mode));
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
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
      seedColor: _brandGreen,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: _brandGreen,
      brightness: Brightness.dark,
    );
    final cardBorder = BorderSide(color: _brandGreen.withValues(alpha: 0.08));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeRoute',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme.copyWith(
          primary: _brandGreen,
          onPrimary: Colors.white,
          secondary: const Color(0xFFC96B5C),
          tertiary: const Color(0xFF274060),
          surface: _brandSurface,
          surfaceContainerHighest: _brandMint,
          error: const Color(0xFFB83B5E),
        ),
        scaffoldBackgroundColor: _brandSurface,
        appBarTheme: const AppBarTheme(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: cardBorder,
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: DividerThemeData(color: Colors.black.withValues(alpha: 0.08), thickness: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _brandGreen.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _brandGreen.withValues(alpha: 0.12)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: _brandGreen, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _brandGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brandGreenDark,
            side: BorderSide(color: _brandGreen.withValues(alpha: 0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _brandGreenDark),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          indicatorColor: _brandGreen.withValues(alpha: 0.16),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, color: baseScheme.onSurfaceVariant),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _brandMint,
          selectedColor: _brandGreen.withValues(alpha: 0.14),
          secondarySelectedColor: _brandGreen.withValues(alpha: 0.14),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          side: BorderSide(color: _brandGreen.withValues(alpha: 0.08)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkScheme.copyWith(
          primary: _brandGreen,
          onPrimary: Colors.white,
          surface: const Color(0xFF111827),
          surfaceContainerHighest: const Color(0xFF1F2937),
          outline: Colors.white.withValues(alpha: 0.12),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 0,
          surfaceTintColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.08), thickness: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111827),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: _brandGreen, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _brandGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          indicatorColor: _brandGreen.withValues(alpha: 0.2),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, color: darkScheme.onSurfaceVariant),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1F2937),
          selectedColor: _brandGreen.withValues(alpha: 0.22),
          secondarySelectedColor: _brandGreen.withValues(alpha: 0.22),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      themeMode: _themeMode,
      locale: Locale(_localeCode),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('sw')],
      home: _isCheckingSession
          ? const SplashScreen()
          : (_session == null
                ? AuthScreen(
                    localeCode: _localeCode,
                    onAuthenticated: _onAuthenticated,
                  )
                : HomeScreen(
                    user: _session!.user,
                    onSignOut: _onSignOut,
                    localeCode: _localeCode,
                    onLocaleChanged: _onLocaleChanged,
                    themeMode: _themeMode,
                    onThemeModeChanged: _onThemeModeChanged,
                  )),
    );
  }
}
