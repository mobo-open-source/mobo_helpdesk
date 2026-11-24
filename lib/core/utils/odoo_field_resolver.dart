import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/company_session_manager.dart';

/// Resolves which of several candidate field names a model actually has.
///
/// Field names move between Odoo versions and modules: `res.users.mobile_phone`
/// only exists when `hr` is installed, while `mobile` comes and goes on
/// `res.partner`. Choosing by server version alone therefore breaks on the
/// databases that do not match the assumption - the request fails with an
/// "Invalid field" error (a bare `KeyError` on Odoo 17 and 18) and the whole
/// screen fails with it.
///
/// `fields_get` answers the question directly: it returns only the fields the
/// model really has, so a name that is not there is simply absent from the
/// reply rather than an error.
///
/// Answers belong to the server, database and user that gave them. The app can
/// be signed in to servers of different versions, one after another, so an
/// answer learned on an Odoo 20 server ("`role_id` exists") must never be used
/// on an Odoo 17 one. [_syncScope] drops them as soon as the signed-in account
/// is not the one that gave them, whichever way the app got there.
class OdooFieldResolver {
  /// Answers already obtained, keyed by model and candidate list.
  ///
  /// Only real answers are cached; a failed request is not, so a temporary
  /// connection problem does not freeze a wrong result for the session.
  static final Map<String, String?> _cache = {};

  /// Answers for [availableFields], keyed by model and candidate list.
  static final Map<String, List<String>> _availableCache = {};

  /// The account the cached answers came from.
  static String? _scope;

  /// Fields a test says a model has, in place of asking a server.
  static final Map<String, Set<String>> _seededFields = {};

  /// Forgets the answers when the signed-in server, database or user is not the
  /// one they came from.
  static Future<void> _syncScope() async {
    final String now;
    try {
      final prefs = await SharedPreferences.getInstance();
      now =
          '${prefs.getString('url')}|${prefs.getString('database')}|'
          '${prefs.getInt('userId')}';
    } catch (_) {
      return; // no stored account to compare with
    }
    if (_scope != null && _scope != now) {
      _cache.clear();
      _availableCache.clear();
    }
    _scope = now;
  }

  /// The first of [candidates] that [model] has, or `null` when it has none.
  static Future<String?> firstAvailableField(
    String model,
    List<String> candidates,
  ) async {
    await _syncScope();
    final cacheKey = '$model:${candidates.join(',')}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': model,
        'method': 'fields_get',
        'args': [
          candidates,
          ['type'],
        ],
        'kwargs': {},
      });

      if (result is Map) {
        for (final candidate in candidates) {
          if (result.containsKey(candidate)) {
            _cache[cacheKey] = candidate;
            return candidate;
          }
        }
        _cache[cacheKey] = null;
      }
    } catch (_) {
      // Left uncached, so the next attempt asks again.
    }

    return _cache[cacheKey];
  }

  /// The members of [candidates] that [model] has, in their own order.
  ///
  /// One request answers for all of them, and a name the model lacks is simply
  /// absent rather than an error, so a read or write built from this list never
  /// names a field the server does not have.
  ///
  /// When the server cannot be asked, [whenUnknown] is returned (every
  /// candidate by default). Give the fields every version has, so that nothing
  /// newer is requested from a server that may not know it.
  static Future<List<String>> availableFields(
    String model,
    List<String> candidates, {
    List<String>? whenUnknown,
  }) async {
    final seeded = _seededFields[model];
    if (seeded != null) {
      return [
        for (final name in candidates)
          if (seeded.contains(name)) name,
      ];
    }

    await _syncScope();
    final cacheKey = '$model:${candidates.join(',')}';
    final cached = _availableCache[cacheKey];
    if (cached != null) return cached;

    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': model,
        'method': 'fields_get',
        'args': [
          candidates,
          ['type'],
        ],
        'kwargs': {},
      });
      if (result is Map) {
        return _availableCache[cacheKey] = [
          for (final name in candidates)
            if (result.containsKey(name)) name,
        ];
      }
    } catch (_) {
      // Left uncached, so the next attempt asks again.
    }
    return whenUnknown ?? candidates;
  }

  /// Whether [model] has [field].
  ///
  /// Fields come and go between Odoo versions without the version number
  /// saying so reliably (`helpdesk.ticket.email_cc` and `helpdesk.team.use_rating`
  /// are gone in Odoo 20, `mail.activity.role_id` is new in it), so a feature
  /// that depends on one asks the server.
  ///
  /// When the server cannot be asked (no connection, no rights), the answer is
  /// [assumeIfUnknown]. A field that older servers have and Odoo 20 dropped is
  /// assumed present (the default: that is how the app behaved before the
  /// check). A field that only newer servers have must be assumed absent:
  /// leaving a feature out never breaks an older server, but asking it for a
  /// field it lacks fails the whole request.
  static Future<bool> hasField(
    String model,
    String field, {
    bool assumeIfUnknown = true,
  }) async {
    final found = await firstAvailableField(model, [field]);
    if (found != null) return true;
    return _cache.containsKey('$model:$field') ? false : assumeIfUnknown;
  }

  /// Records what a server would have answered for [field], so a test can
  /// say "this server has / lacks it" without one.
  @visibleForTesting
  static void debugSetFieldAnswer(String model, String field, bool exists) {
    _cache['$model:$field'] = exists ? field : null;
  }

  /// Says which fields [model] has, for [availableFields], so a test can stand
  /// in for a server of a given version.
  @visibleForTesting
  static void debugSetAvailableFields(String model, Set<String> fields) {
    _seededFields[model] = fields;
  }

  /// Forgets every resolved field.
  ///
  /// Also called when the account or server changes; [_syncScope] makes the
  /// same happen on its own for any change this is not called for.
  static void clearCache() {
    _cache.clear();
    _availableCache.clear();
    _seededFields.clear();
  }
}
