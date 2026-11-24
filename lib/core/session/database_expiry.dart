import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/services/auth_service.dart';
import '../../features/login/presentation/pages/url_database_screen.dart';
import '../navigation/navigation_keys.dart';
import '../usecases/reset_session_usecase.dart';
import '../utils/app_logger.dart';
import '../widgets/snackbar.dart';

/// Thrown when the Odoo database behind a session has passed its expiration
/// date (the one Odoo Enterprise shows as "This database has expired").
class DatabaseExpiredException implements Exception {
  const DatabaseExpiredException();

  static const String message =
      'This database has expired. Please contact your administrator or '
      'Odoo to renew the subscription.';

  @override
  String toString() => 'Database Expired';
}

/// Checks the expiration date Odoo publishes in its session info.
class DatabaseExpiry {
  /// Whether the database behind [sessionId] has expired.
  ///
  /// Returns false when the server reports no expiration date (community
  /// editions, or databases with a valid subscription) or the call fails, so
  /// an unreachable server is never mistaken for an expired database.
  static Future<bool> isExpired({
    required String serverUrl,
    required String sessionId,
  }) async {
    final raw = await _expirationDate(serverUrl, sessionId);
    if (raw == null || raw.isEmpty) return false;

    // Odoo sends "YYYY-MM-DD HH:MM:SS" (UTC), or just "YYYY-MM-DD".
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2}))?',
    ).firstMatch(raw.trim());
    if (match == null) return false;
    final parts = [
      for (var i = 1; i <= 6; i++) int.tryParse(match.group(i) ?? '') ?? 0,
    ];
    final expiry = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    // Same rule as the web client: expired once the days left, rounded, reach 0.
    final daysLeft =
        expiry.difference(DateTime.now().toUtc()).inSeconds / 86400;
    return daysLeft.round() <= 0;
  }

  /// The `database.expiration_date` value, from the session info the web
  /// client reads, or - when that does not carry it - straight from the
  /// config parameter. Null when neither can be read.
  static Future<String?> _expirationDate(
    String serverUrl,
    String sessionId,
  ) async {
    final url = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final auth = AuthService();
    try {
      final info = await auth.getSessionInfo(url, sessionId);
      final value = info['expiration_date'];
      if (value is String && value.isNotEmpty) return value;
    } catch (e) {
      AppLogger.warning('Session info unavailable for expiry check: $e');
    }
    try {
      final value = await auth.callKwWithSession(
        url: url,
        sessionId: sessionId,
        payload: {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'ir.config_parameter',
            'method': 'get_param',
            'args': ['database.expiration_date'],
            'kwargs': {},
          },
          'id': 1,
        },
      );
      if (value is String && value.isNotEmpty) return value;
    } catch (e) {
      AppLogger.warning('Expiration parameter unavailable: $e');
    }
    return null;
  }

  static bool _enforcing = false;

  /// Signs the user out and returns to the login screen when the database of
  /// the stored session has expired. Returns true when it did.
  static Future<bool> enforceOnStoredSession() async {
    if (_enforcing) return false;
    _enforcing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('isLoggedIn') ?? false)) return false;
      final expired = await isExpired(
        serverUrl: prefs.getString('url') ?? '',
        sessionId: prefs.getString('sessionId') ?? '',
      );
      if (!expired) return false;

      await ResetSessionUseCase().execute();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: UrlDatabaseScreen.routeName),
          builder: (_) => const UrlDatabaseScreen(),
        ),
        (_) => false,
      );
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        CustomSnackBar.showError(context, DatabaseExpiredException.message);
      }
      return true;
    } finally {
      _enforcing = false;
    }
  }
}
