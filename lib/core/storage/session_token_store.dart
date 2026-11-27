import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps Odoo session ids (bearer credentials) in the platform keystore
/// (Android Keystore / iOS Keychain) instead of plain `SharedPreferences`.
///
/// Two kinds of entries are stored:
/// - the active session id, and
/// - one session id per saved account (url + database + login), used by the
///   account switcher.
class SessionTokenStore {
  SessionTokenStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _activeKey = 'odoo_active_session_id';
  static const _accountPrefix = 'odoo_account_session_';
  static const _legacyPrefsKey = 'sessionId';
  static const _accountsPrefsKey = 'loggedInAccounts';

  static String accountKey(Object? url, Object? database, Object? login) =>
      '$_accountPrefix${'$url'.trim()}|${'$database'.trim()}|${'$login'.trim()}';

  // ---- Active session ----------------------------------------------------

  static Future<String?> getActive() async {
    try {
      final value = await _storage.read(key: _activeKey);
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setActive(String sessionId) async {
    if (sessionId.isEmpty) {
      await clearActive();
      return;
    }
    await _storage.write(key: _activeKey, value: sessionId);
  }

  static Future<void> clearActive() => _storage.delete(key: _activeKey);

  // ---- Per-account sessions ---------------------------------------------

  static Future<String?> getAccount(
    Object? url,
    Object? database,
    Object? login,
  ) async {
    try {
      return await _storage.read(key: accountKey(url, database, login));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setAccount(
    Object? url,
    Object? database,
    Object? login,
    String sessionId,
  ) async {
    final key = accountKey(url, database, login);
    if (sessionId.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: sessionId);
    }
  }

  static Future<void> removeAccount(
    Object? url,
    Object? database,
    Object? login,
  ) => _storage.delete(key: accountKey(url, database, login));

  /// Removes the session ids of all saved accounts (not the active one).
  static Future<void> clearAccountTokens() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_accountPrefix)) await _storage.delete(key: key);
    }
  }

  /// Removes every stored session id (active and per-account). Used on logout.
  static Future<void> clearAll() async {
    await clearActive();
    await clearAccountTokens();
  }

  // ---- Migration ---------------------------------------------------------

  /// One-time move of session ids that older builds left in plaintext
  /// `SharedPreferences`. Safe to call on every launch; it does nothing once
  /// the plaintext copies are gone. Existing users stay signed in.
  static Future<void> migrateFromPlaintext() async {
    final prefs = await SharedPreferences.getInstance();

    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null) {
      if (legacy.isNotEmpty && await getActive() == null) {
        await setActive(legacy);
      }
      await prefs.remove(_legacyPrefsKey);
    }

    final accountsJson = prefs.getString(_accountsPrefsKey);
    if (accountsJson != null) {
      try {
        final accounts = (jsonDecode(accountsJson) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        var changed = false;
        for (final a in accounts) {
          final sid = a.remove('sessionId');
          if (sid != null) {
            changed = true;
            if (sid.toString().isNotEmpty) {
              await setAccount(
                a['url'],
                a['database'],
                a['userLogin'],
                sid.toString(),
              );
            }
          }
        }
        if (changed) {
          await prefs.setString(_accountsPrefsKey, jsonEncode(accounts));
        }
      } catch (_) {
        // Unreadable list: leave it for the normal flow to overwrite.
      }
    }
  }
}
