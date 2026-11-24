import 'dart:convert';
import 'dart:io';

import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../../core/auth/services/auth_service.dart';

/// Abstract remote datasource for login-related operations with an Odoo server.
///
/// Provides methods to discover available databases and validate login credentials
/// by checking for the presence of the Enterprise edition.
abstract class LoginRemoteDatasource {
  /// Fetches the list of available databases from an Odoo server.
  ///
  /// - Automatically normalizes the URL (adds https:// if missing, removes trailing slash).
  /// - Uses a raw HTTP POST request to `/web/database/list` endpoint.
  /// - Configures a custom [HttpClient] with reasonable timeouts and ignores bad certificates
  ///   (useful for self-signed certificates during development or internal servers).
  ///
  /// Throws a generic error message if the request fails.
  Future<List<String>> fetchDatabaseList(String url);

  /// Authenticates with the Odoo server and checks whether the **Enterprise Edition** is installed.
  ///
  /// This method is typically used during login to determine if certain enterprise-only
  /// features should be enabled.
  ///
  /// Parameters:
  ///   - [url]: Base URL of the Odoo server.
  ///   - [database]: Database name to connect to.
  ///   - [username]: Login username.
  ///   - [password]: Login password.
  ///
  /// Returns:
  ///   `true` if the `web_enterprise` module is installed, `false` otherwise.
  ///
  /// Throws:
  ///   - `'2FA Required'` if two-factor authentication is detected.
  ///   - Original error message (lowercased) for other authentication failures.
  Future<bool> fetchVersionInfo(
    String url,
    String database,
    String username,
    String password,
  );
}

/// Concrete implementation of [LoginRemoteDatasource] using raw HTTP calls and the `odoo_rpc` package.
class LoginRemoteDatasourceImpl extends LoginRemoteDatasource {
  /// Fetches available Odoo databases using a direct JSON-RPC call.
  ///
  /// See [LoginRemoteDatasource.fetchDatabaseList] for detailed behavior.
  @override
  Future<List<String>> fetchDatabaseList(String url) async {
    try {
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      final HttpClient httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 10)
        ..maxConnectionsPerHost = 5
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final String responseBody;
      try {
        final request = await httpClient.postUrl(
          Uri.parse('$normalizedUrl/web/database/list'),
        );

        request.headers.set('Content-Type', 'application/json');
        request.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {},
            'id': 1,
          }),
        );

        final response = await request.close();
        responseBody = await response.transform(utf8.decoder).join();
      } finally {
        // Closed on failure too, so a server that cannot be reached does not
        // leave the connection behind.
        httpClient.close();
      }

      final jsonResponse = jsonDecode(responseBody);

      if (jsonResponse['result'] is List) {
        return List<String>.from(jsonResponse['result']);
      }
      return [];
    } catch (error) {
      // The cause is what tells a failed TLS handshake apart from a refused
      // connection or an HTML reply, and it is the only thing
      // [LoginErrorFormatter] can classify - flattening it to a fixed sentence
      // left every failure looking the same.
      throw 'Error fetching database list: $error';
    }
  }

  /// Authenticates the user and checks for the presence of the Enterprise module (`web_enterprise`).
  ///
  /// Uses [OdooClient] from the `odoo_rpc` package for authentication.
  /// See [LoginRemoteDatasource.fetchVersionInfo] for detailed behavior and exceptions.
  @override
  Future<bool> fetchVersionInfo(
    String url,
    String database,
    String username,
    String password,
  ) async {
    try {
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      final client = OdooClient(normalizedUrl);

      final session = await client.authenticate(database, username, password);

      try {
        final count = await client.callKw({
          'model': 'ir.module.module',
          'method': 'search_count',
          'args': [
            [
              ['name', '=', 'web_enterprise'],
              ['state', '=', 'installed'],
            ],
          ],
          'kwargs': {},
        });

        return count > 0 ?? false;
      } catch (error) {
        // This is the first request of the login, and a user without rights on
        // `ir.module.module` - a portal user in particular - fails right here,
        // before the helpdesk access check ever runs. Reported as the access
        // outcome so the login screens raise the matching dialog instead of
        // showing a raw rights error under the fields.
        final authService = AuthService();
        if (!authService.isAccessError(error)) rethrow;

        final isPortalUser = await authService.isPortalUserViaClient(
          client,
          userId: session.userId,
          majorVersion: authService.parseMajorVersion(session.serverVersion),
        );
        throw isPortalUser ? 'Portal Access' : 'Access Denied';
      }
    } catch (e) {
      // Sentinels are matched by the bloc as-is, so they must keep their casing.
      if (e == 'Portal Access' || e == 'Access Denied') {
        rethrow;
      }
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('null') ||
          errorStr.contains('two factor') ||
          errorStr.contains('2fa')) {
        throw '2FA Required';
      }
      throw errorStr;
    }
  }
}
