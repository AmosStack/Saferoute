import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_models.dart';
import '../models/user_settings.dart';

class UserSettingsService {
  UserSettingsService._();

  static const String _profileKey = 'safe_route_profile';
  static const String _contactsKey = 'safe_route_trusted_contacts';
  static const String _localeKey = 'safe_route_locale';

  static Future<UserProfileDraft> loadProfile({AuthUser? fallbackUser}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return UserProfileDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Fall back to the session user below.
      }
    }

    return UserProfileDraft(
      displayName: fallbackUser?.name ?? '',
      email: fallbackUser?.email ?? '',
      phone: fallbackUser?.phone ?? '',
      bio: '',
    );
  }

  static Future<void> saveProfile(UserProfileDraft profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  static Future<List<TrustedContact>> loadTrustedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null || raw.isEmpty) {
      return const <TrustedContact>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => TrustedContact.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const <TrustedContact>[];
    }
  }

  static Future<void> saveTrustedContacts(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsKey,
      jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
    );
  }

  static Future<void> upsertTrustedContact(TrustedContact contact) async {
    final contacts = await loadTrustedContacts();
    final index = contacts.indexWhere((entry) => entry.id == contact.id);
    final updated = [...contacts];
    if (index == -1) {
      updated.add(contact);
    } else {
      updated[index] = contact;
    }
    await saveTrustedContacts(updated);
  }

  static Future<void> deleteTrustedContact(String id) async {
    final contacts = await loadTrustedContacts();
    await saveTrustedContacts(contacts.where((contact) => contact.id != id).toList());
  }

  static Future<String> loadLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localeKey);
    if (raw == 'sw') {
      return 'sw';
    }
    return 'en';
  }

  static Future<void> setLocaleCode(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode == 'sw' ? 'sw' : 'en');
  }
}
