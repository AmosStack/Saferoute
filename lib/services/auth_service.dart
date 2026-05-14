import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_models.dart';
import 'backend_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'auth_session';

  Future<AuthSession?> getStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionKey);
    if (sessionJson == null || sessionJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
      return AuthSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Register with email using the backend API
  Future<AuthSession> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // Call backend API
      final result = await BackendService.register(
        name: name,
        email: email,
        password: password,
      );

      if (result == null) {
        throw AuthException('Registration failed. Please try again.');
      }

      final token = result['token'] as String?;
      final userJson = result['user'] as Map<String, dynamic>?;

      if (token == null || userJson == null) {
        throw AuthException('Invalid response from server');
      }

      final session = AuthSession(
        token: token,
        user: AuthUser(
          id: userJson['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          name: userJson['name'] as String? ?? name,
          email: userJson['email'] as String? ?? email,
          phone: phone,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));

      return session;
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  /// Sign in with email using the backend API
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Call backend API
      final result = await BackendService.login(
        email: email,
        password: password,
      );

      if (result == null) {
        throw AuthException('Invalid email or password.');
      }

      final token = result['token'] as String?;
      final userJson = result['user'] as Map<String, dynamic>?;

      if (token == null || userJson == null) {
        throw AuthException('Invalid response from server');
      }

      final session = AuthSession(
        token: token,
        user: AuthUser(
          id: userJson['id'] as int? ?? 0,
          name: userJson['name'] as String? ?? 'User',
          email: userJson['email'] as String? ?? email,
          phone: '',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));

      return session;
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  Future<AuthSession> signInWithGoogle() async {
    final session = AuthSession(
      token: 'google-token-${DateTime.now().millisecondsSinceEpoch}',
      user: AuthUser(
        id: DateTime.now().millisecondsSinceEpoch,
        name: 'Google User',
        email: 'google.user@saferoute.app',
        phone: '',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    return session;
  }

  Future<AuthSession> signInWithFacebook() async {
    final session = AuthSession(
      token: 'facebook-token-${DateTime.now().millisecondsSinceEpoch}',
      user: AuthUser(
        id: DateTime.now().millisecondsSinceEpoch,
        name: 'Facebook User',
        email: 'facebook.user@saferoute.app',
        phone: '',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    return session;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}