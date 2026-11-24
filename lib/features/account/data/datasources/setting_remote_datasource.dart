import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';

/// Contract for remote settings operations such as
/// fetching languages, currencies, timezones,
/// updating user preferences, and managing cache.
abstract class SettingRemoteDatasource {
  /// Returns list of active languages.
  Future<List<Map<String, dynamic>>> loadLanguages();

  /// Updates user's language preference.
  Future<void> updateLanguage(String langCode);

  /// Returns list of active currencies.
  Future<List<Map<String, dynamic>>> loadCurrencies();

  /// Returns list of available timezones.
  Future<List<Map<String, dynamic>>> loadTimezones();

  /// Updates user's timezone.
  Future<void> updateTz(String tz);

  /// Returns total cache size in bytes.
  Future<int> getCacheSize();

  /// Clears temporary cache.
  Future<void> clearCache();
}

/// Implementation of [SettingRemoteDatasource]
/// using API calls and local storage.
class SettingRemoteDatasourceImpl implements SettingRemoteDatasource {
  /// Fetches languages from backend.
  @override
  Future<List<Map<String, dynamic>>> loadLanguages() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.lang',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['code', 'name', 'iso_code', 'direction'],
          'order': 'name',
        },
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      throw 'Language error';
    }
  }

  /// Fetches currencies from backend.
  @override
  Future<List<Map<String, dynamic>>> loadCurrencies() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.currency',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
          ['name', 'full_name', 'symbol', 'position', 'rounding'],
        ],
        'kwargs': {'order': 'name'},
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      throw 'Currency error';
    }
  }

  /// Fetches timezones from backend or fallback list.
  @override
  Future<List<Map<String, dynamic>>> loadTimezones() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [
          ['tz'],
        ],
        'kwargs': {
          'attributes': ['selection', 'string'],
        },
      });

      final tzField = (response != null)
          ? response['tz'] as Map<String, dynamic>?
          : null;
      final selection = tzField != null
          ? tzField['selection'] as List<dynamic>?
          : null;

      List<Map<String, dynamic>> timezones = [];

      if (selection != null && selection.isNotEmpty) {
        timezones = selection.map<Map<String, dynamic>>((item) {
          if (item is List && item.length >= 2) {
            return {'code': item[0].toString(), 'name': item[1].toString()};
          }
          return {'code': item.toString(), 'name': item.toString()};
        }).toList();
      }

      if (timezones.isEmpty) {
        timezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'Europe/Brussels', 'name': 'Europe/Brussels'},
          {'code': 'Asia/Kolkata', 'name': 'Asia/Kolkata'},
          {'code': 'America/New_York', 'name': 'America/New_York'},
        ];
      }

      return timezones;
    } catch (e) {
      throw 'Timezone error';
    }
  }

  /// Calculates cache size recursively.
  @override
  Future<int> getCacheSize() async {
    final dir = await getTemporaryDirectory();
    return _getSize(dir);
  }

  /// Recursively computes file/directory size.
  Future<int> _getSize(FileSystemEntity file) async {
    if (file is File) return await file.length();

    if (file is Directory) {
      int total = 0;
      await for (final child in file.list()) {
        total += await _getSize(child);
      }
      return total;
    }

    return 0;
  }

  /// Clears cache directory.
  @override
  Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    await _delete(dir);
  }

  /// Recursively deletes files/directories.
  Future<void> _delete(FileSystemEntity file) async {
    if (file is Directory) {
      await for (final child in file.list()) {
        await _delete(child);
      }
    }

    try {
      await file.delete();
    } catch (_) {}
  }

  /// Updates user language in backend.
  @override
  Future<void> updateLanguage(String langCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          {'lang': langCode},
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw "Failed to update language";
    }
  }

  /// Updates user timezone in backend.
  @override
  Future<void> updateTz(String tz) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          {'tz': tz},
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw "Failed to update timezone";
    }
  }
}
