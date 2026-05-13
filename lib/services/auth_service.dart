import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_models.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'auth_session';
  static const String _passwordKey = 'auth_password';

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

  Future<AuthSession> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final session = AuthSession(
      token: 'local-token-${DateTime.now().millisecondsSinceEpoch}',
      user: AuthUser(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        email: email,
        phone: phone,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    await prefs.setString(_passwordKey, password);
    return session;
  }

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = await getStoredSession();
    final storedPassword = prefs.getString(_passwordKey);

    if (stored == null || storedPassword == null) {
      throw const AuthException('No registered account found. Please register first.');
    }
    if (stored.user.email.toLowerCase() != email.toLowerCase() || storedPassword != password) {
      throw const AuthException('Invalid email or password.');
    }

    return stored;
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