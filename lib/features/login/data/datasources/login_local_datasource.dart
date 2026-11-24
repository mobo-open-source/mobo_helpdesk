import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Abstract data source for managing local URL history using SharedPreferences.
///
/// This datasource handles persistence of recently used Odoo server URLs
/// (with protocol, database, and username) for quick login selection.
abstract class LoginLocalDatasource {
  /// Saves a login entry to the URL history.
  ///
  /// - Automatically detects and normalizes `http://` or `https://` prefixes.
  /// - Removes any duplicate entry for the same protocol + URL.
  /// - Inserts the new entry at the top (most recent first).
  /// - Limits history to the 10 most recent entries.
  ///
  /// Parameters:
  ///   - [protocol]: The protocol (usually 'http://' or 'https://').
  ///   - [url]: The server URL (without protocol).
  ///   - [database]: The Odoo database name.
  ///   - [username]: The username used for login.
  Future<void> saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  });

  /// Loads URL history filtered by protocol.
  ///
  /// Returns a map where:
  /// - Key = Full URL (e.g., "https://example.com")
  /// - Value = Map containing `'db'` and `'username'`
  ///
  /// Only entries matching the requested [protocol] (or having no protocol)
  /// are included.
  Future<Map<String, Map<String, String>>> loadUrlHistoryForProtocol({
    required String protocol,
  });
}

/// Concrete implementation of [LoginLocalDatasource] using SharedPreferences.
///
/// Stores history as a JSON-encoded list of entries under the key `'urlHistory'`.
class LoginLocalDatasourceImpl implements LoginLocalDatasource {
  /// Saves a new login entry to history with deduplication and size limit.
  ///
  /// See [LoginLocalDatasource.saveUrlHistory] for full behavior.
  @override
  Future<void> saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https://';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http://';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }

    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);

    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  /// Loads and decodes the URL history, returning a map grouped by full URL.
  ///
  /// See [LoginLocalDatasource.loadUrlHistoryForProtocol] for details.
  @override
  Future<Map<String, Map<String, String>>> loadUrlHistoryForProtocol({
    required String protocol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('urlHistory') ?? [];

    final Map<String, Map<String, String>> history = {};

    for (var entry in raw) {
      try {
        final decoded = jsonDecode(entry) as Map<String, dynamic>;

        final p = decoded['protocol'] as String? ?? protocol;
        final url = decoded['url'] as String;
        final fullUrl = '$p$url';

        history[fullUrl] = {
          'db': decoded['db'] ?? '',
          'username': decoded['username'] ?? '',
        };
      } catch (_) {}
    }

    return history;
  }
}
