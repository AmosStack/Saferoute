import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_models.dart';
import 'backend_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'auth_session';
  static const String _googleOAuthClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue:
        '105928817756-d4pbc059dccu5o7jq63b6ep9mt4shdu9.apps.googleusercontent.com',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? _googleOAuthClientId : null,
    serverClientId: _googleOAuthClientId,
  );

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

      final error = result['error'] as String?;
      if (error != null && error.isNotEmpty) {
        throw AuthException(error);
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
    } on AuthException {
      rethrow;
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

      final error = result['error'] as String?;
      if (error != null && error.isNotEmpty) {
        throw AuthException(error);
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
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  Future<AuthSession> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleAccount = await _googleSignIn.signInSilently();
      googleAccount ??= await _googleSignIn.signIn();
      if (googleAccount == null) {
        throw const AuthException('Google sign-in was cancelled.');
      }

      final googleAuth = await googleAccount.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google did not return a sign-in token.');
      }

      final result = await BackendService.loginWithGoogle(idToken: idToken);
      if (result == null) {
        throw const AuthException('Google login failed. Please try again.');
      }

      final error = result['error'] as String?;
      if (error != null && error.isNotEmpty) {
        throw AuthException(error);
      }

      final token = result['token'] as String?;
      final userJson = result['user'] as Map<String, dynamic>?;

      if (token == null || userJson == null) {
        throw const AuthException('Invalid response from server');
      }

      final session = AuthSession(
        token: token,
        user: AuthUser(
          id: userJson['id'] as int? ?? 0,
          name:
              userJson['name'] as String? ??
              googleAccount.displayName ??
              'Google User',
          email: userJson['email'] as String? ?? googleAccount.email,
          phone: '',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
      return session;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Google login failed: $e');
    }
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
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google sign-out failures and always clear the local session.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
