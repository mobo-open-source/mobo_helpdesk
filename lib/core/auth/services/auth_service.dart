import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../security/self_signed.dart';
import '../../session/models/session_model.dart';

/// Service responsible for handling authentication with an Odoo backend.
///
/// This class provides methods to authenticate users against an Odoo server,
/// retrieve session information, and fetch additional user data such as
/// company details, system permissions, and allowed companies.
///
/// It supports two authentication flows:
/// 1. **Session-based authentication** – Used when a `sessionId` is already available.
/// 2. **Credential-based authentication** – Traditional login with database, username, and password.
///
/// The service uses the `odoo_rpc` package for standard authentication and
/// manual HTTP calls (via `ioClient`) for session-based operations to ensure
/// compatibility with different Odoo versions (especially v13+ and v18+).
///
/// Key features:
/// - Parses Odoo server version to determine API behavior.
/// - Fetches user company information and multi-company support.
/// - Checks if the user belongs to the `helpdesk.group_helpdesk_manager` group.
/// - Handles differences in `has_group` method signature between Odoo versions.
/// - Returns a rich [SessionModel] containing all necessary session and user context.
class AuthService {
  /// Parses the major version number from the Odoo server version string.
  ///
  /// Example: "18.0+e" → 18, "16.0" → 16
  ///
  /// Used to handle version-specific differences in Odoo RPC calls.
  int parseMajorVersion(String serverVersion) {
    // ignore: deprecated_member_use
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Retrieves session information from Odoo using an existing session ID.
  ///
  /// Makes a direct HTTP POST request to `/web/session/get_session_info`.
  Future<Map<String, dynamic>> getSessionInfo(
    String url,
    String sessionId,
  ) async {
    final response = await ioClient.post(
      Uri.parse('$url/web/session/get_session_info'),
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': url,
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {},
        "id": 1,
      }),
    );
    final data = jsonDecode(response.body);
    return Map<String, dynamic>.from(data['result']);
  }

  /// Makes a generic `call_kw` request using an existing session ID.
  ///
  /// Used for operations that require an active session cookie.
  Future<dynamic> callKwWithSession({
    required String url,
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await ioClient.post(
      Uri.parse('$url/web/dataset/call_kw'),
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(res.body);
    if (data['error'] != null) throw data['error'];
    return data['result'];
  }

  /// Checks whether the `helpdesk` module is installed, using an already
  /// established session cookie.
  ///
  /// Used to tell a genuine permission failure (module installed, user not
  /// in either helpdesk group) apart from a missing-module database (where
  /// `has_group` on a helpdesk-defined group silently returns `false`
  /// because the group itself doesn't exist).
  Future<bool> _isHelpdeskInstalledViaSession({
    required String url,
    required String sessionId,
  }) async {
    try {
      final count = await callKwWithSession(
        url: url,
        sessionId: sessionId,
        payload: {
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "model": "ir.module.module",
            "method": "search_count",
            "args": [
              [
                ['name', '=', 'helpdesk'],
                ['state', '=', 'installed'],
              ],
            ],
            "kwargs": {},
          },
          "id": 1,
        },
      );
      return (count ?? 0) > 0;
    } catch (_) {
      return true;
    }
  }

  /// Same check as [_isHelpdeskInstalledViaSession], using an authenticated
  /// [OdooClient] instead of a raw session cookie.
  Future<bool> _isHelpdeskInstalledViaClient(OdooClient client) async {
    try {
      final count = await client.callKw({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            ['name', '=', 'helpdesk'],
            ['state', '=', 'installed'],
          ],
        ],
        'kwargs': {},
      });
      return (count ?? 0) > 0;
    } catch (_) {
      return true;
    }
  }

  /// Whether an error from Odoo is a rights failure rather than a transport or
  /// server problem.
  ///
  /// Matches the wording Odoo uses for `AccessError` / `AccessDenied` and for
  /// field-level refusals ("not allowed to access").
  bool isAccessError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('accesserror') ||
        text.contains('access denied') ||
        text.contains('accessdenied') ||
        text.contains('not allowed');
  }

  /// Checks whether the signed-in user is a portal (customer) user, using an
  /// already established session cookie.
  ///
  /// Portal users are never in a helpdesk group, so they fail the access check
  /// the same way an internal user without helpdesk rights does. Telling the
  /// two apart lets the app explain the real reason: a customer account cannot
  /// be used with this app at all, while an internal user only needs rights.
  ///
  /// A failure here is treated as "not a portal user", so a server that does
  /// not answer this call still reports the plain access error.
  Future<bool> isPortalUserViaSession({
    required String url,
    required String sessionId,
    required int userId,
    required int majorVersion,
  }) async {
    // `share` is readable by a user on its own record, so this answers even
    // when the user has no rights on anything else.
    try {
      final result = await callKwWithSession(
        url: url,
        sessionId: sessionId,
        payload: {
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "model": "res.users",
            "method": "read",
            "args": [
              [userId],
              ["share"],
            ],
            "kwargs": {},
          },
          "id": 1,
        },
      );
      if (result is List && result.isNotEmpty) {
        return result[0]['share'] == true;
      }
    } catch (_) {}

    try {
      final result = await callKwWithSession(
        url: url,
        sessionId: sessionId,
        payload: {
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "model": "res.users",
            "method": "has_group",
            "args": majorVersion >= 18
                ? [userId, "base.group_portal"]
                : ["base.group_portal"],
            "kwargs": {},
          },
          "id": 1,
        },
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Same check as [isPortalUserViaSession], using an authenticated
  /// [OdooClient] instead of a raw session cookie.
  Future<bool> isPortalUserViaClient(
    OdooClient client, {
    required int userId,
    required int majorVersion,
  }) async {
    // See [isPortalUserViaSession]: the `share` flag is the reading a user is
    // allowed to take of its own record, so it is tried first.
    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['share'],
        ],
        'kwargs': {},
      });
      if (result is List && result.isNotEmpty) {
        return result[0]['share'] == true;
      }
    } catch (_) {}

    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'has_group',
        'args': majorVersion >= 18
            ? [userId, 'base.group_portal']
            : ['base.group_portal'],
        'kwargs': {},
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Helper method to parse company data returned from Odoo.
  ///
  /// Odoo sometimes returns company as a list `[id, name]` or as a map.
  Map<String, dynamic>? _parseCompany(dynamic value) {
    if (value == null) return null;

    if (value is List && value.length >= 2) {
      return {'id': value[0], 'name': value[1]};
    }

    if (value is Map) {
      return {
        'id': value['id'],
        'name': value['display_name'] ?? value['name'],
      };
    }
    return null;
  }

  /// Authenticates with an Odoo server and returns a [SessionModel].
  ///
  /// Supports two modes:
  /// - If [sessionId] is provided: Validates and enriches the existing session.
  /// - If [sessionId] is null: Performs a fresh login using credentials.
  ///
  /// Handles version-specific logic for Odoo 13+ (multi-company) and Odoo 18+
  /// (`has_group` method signature changes).
  ///
  /// Throws exceptions on authentication or RPC failures.
  Future<SessionModel?> authenticateOdoo({
    required String url,
    required String database,
    required String username,
    required String password,
    sessionId,
  }) async {
    try {
      final client = OdooClient(url);
      final OdooSession session;
      int userId = 0;

      if (sessionId != null) {
        final sessionInfo = await getSessionInfo(url, sessionId);

        final int userId = sessionInfo['uid'];
        final String serverVersion = sessionInfo['server_version'];
        final int majorVersion = parseMajorVersion(serverVersion);

        // A portal user is not allowed to read this field on `res.users`, so the
        // request fails here - before the helpdesk groups are ever checked.
        // Reporting the raw rights error would tell the user nothing useful, so
        // it is turned into the same outcome the group check produces.
        final dynamic userData;
        try {
          userData = await callKwWithSession(
            url: url,
            sessionId: sessionId,
            payload: {
              "jsonrpc": "2.0",
              "method": "call",
              "params": {
                "model": "res.users",
                "method": "read",
                "args": [
                  [userId],
                  ["company_id"],
                ],
                "kwargs": {},
              },
              "id": 1,
            },
          );
        } catch (error) {
          if (!isAccessError(error)) rethrow;
          final isPortalUser = await isPortalUserViaSession(
            url: url,
            sessionId: sessionId,
            userId: userId,
            majorVersion: majorVersion,
          );
          throw Exception(isPortalUser ? "Portal Access" : "Access Denied");
        }

        final company = _parseCompany(userData[0]['company_id']);

        bool isManager = false;
        bool isUser = false;

        if (majorVersion >= 18) {
          isManager =
              await callKwWithSession(
                url: url,
                sessionId: sessionId,
                payload: {
                  "jsonrpc": "2.0",
                  "method": "call",
                  "params": {
                    "model": "res.users",
                    "method": "has_group",
                    "args": [userId, "helpdesk.group_helpdesk_manager"],
                    "kwargs": {},
                  },
                  "id": 1,
                },
              ) ==
              true;

          isUser =
              await callKwWithSession(
                url: url,
                sessionId: sessionId,
                payload: {
                  "jsonrpc": "2.0",
                  "method": "call",
                  "params": {
                    "model": "res.users",
                    "method": "has_group",
                    "args": [userId, "helpdesk.group_helpdesk_user"],
                    "kwargs": {},
                  },
                  "id": 1,
                },
              ) ==
              true;
        } else {
          isManager =
              await callKwWithSession(
                url: url,
                sessionId: sessionId,
                payload: {
                  "jsonrpc": "2.0",
                  "method": "call",
                  "params": {
                    "model": "res.users",
                    "method": "has_group",
                    "args": ["helpdesk.group_helpdesk_manager"],
                    "kwargs": {},
                  },
                  "id": 1,
                },
              ) ==
              true;

          isUser =
              await callKwWithSession(
                url: url,
                sessionId: sessionId,
                payload: {
                  "jsonrpc": "2.0",
                  "method": "call",
                  "params": {
                    "model": "res.users",
                    "method": "has_group",
                    "args": ["helpdesk.group_helpdesk_user"],
                    "kwargs": {},
                  },
                  "id": 1,
                },
              ) ==
              true;
        }

        if (!isManager && !isUser) {
          final helpdeskInstalled = await _isHelpdeskInstalledViaSession(
            url: url,
            sessionId: sessionId,
          );
          if (!helpdeskInstalled) {
            throw Exception("Module Missing");
          }
          final isPortalUser = await isPortalUserViaSession(
            url: url,
            sessionId: sessionId,
            userId: userId,
            majorVersion: majorVersion,
          );
          if (isPortalUser) {
            throw Exception("Portal Access");
          }
          throw Exception("Access Denied");
        }

        bool isSystem = isManager;

        List<int> allowedCompanyIds = [];
        if (majorVersion >= 13) {
          final companiesRes = await callKwWithSession(
            url: url,
            sessionId: sessionId,
            payload: {
              "jsonrpc": "2.0",
              "method": "call",
              "params": {
                "model": "res.users",
                "method": "read",
                "args": [
                  [userId],
                  ["company_ids"],
                ],
                "kwargs": {},
              },
              "id": 1,
            },
          );

          if (companiesRes is List && companiesRes.isNotEmpty) {
            allowedCompanyIds =
                (companiesRes[0]['company_ids'] as List?)?.cast<int>() ?? [];
          }
        }

        return SessionModel(
          sessionId: sessionId,
          userId: userId,
          userLogin: sessionInfo['username'],
          userName: sessionInfo['name'],
          serverVersion: majorVersion.toString(),
          version: majorVersion,
          // Language and timezone sit in `user_context`; Odoo has no
          // top-level `lang` or `tz` in `session_info`.
          userLang: (sessionInfo['user_context'] as Map?)?['lang'],
          userTimezone: (sessionInfo['user_context'] as Map?)?['tz'],
          partnerId: sessionInfo['partner_id'],
          companyId: company?['id'],
          companyName: company?['name'],
          isSystem: isSystem,
          allowedCompanyIds: allowedCompanyIds,
        );
      } else {
        session = await client.authenticate(database, username, password);
        userId = session.userId;

        final int majorVersion = parseMajorVersion(session.serverVersion);

        // See the session branch above: a portal user is refused this read, so
        // the rights failure is mapped to the access outcome here as well.
        final dynamic userData;
        try {
          userData = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [userId],
              ['company_id'],
            ],
            'kwargs': {},
          });
        } catch (error) {
          if (!isAccessError(error)) rethrow;
          final isPortalUser = await isPortalUserViaClient(
            client,
            userId: session.userId,
            majorVersion: majorVersion,
          );
          throw Exception(isPortalUser ? "Portal Access" : "Access Denied");
        }

        bool isManager = false;
        bool isUser = false;

        if (majorVersion >= 18) {
          isManager =
              await client.callKw({
                'model': 'res.users',
                'method': 'has_group',
                'args': [session.userId, 'helpdesk.group_helpdesk_manager'],
                'kwargs': {},
              }) ==
              true;

          isUser =
              await client.callKw({
                'model': 'res.users',
                'method': 'has_group',
                'args': [session.userId, 'helpdesk.group_helpdesk_user'],
                'kwargs': {},
              }) ==
              true;
        } else {
          isManager =
              await client.callKw({
                'model': 'res.users',
                'method': 'has_group',
                'args': ['helpdesk.group_helpdesk_manager'],
                'kwargs': {},
              }) ==
              true;

          isUser =
              await client.callKw({
                'model': 'res.users',
                'method': 'has_group',
                'args': ['helpdesk.group_helpdesk_user'],
                'kwargs': {},
              }) ==
              true;
        }

        if (!isManager && !isUser) {
          final helpdeskInstalled = await _isHelpdeskInstalledViaClient(client);
          if (!helpdeskInstalled) {
            throw Exception("Module Missing");
          }
          final isPortalUser = await isPortalUserViaClient(
            client,
            userId: session.userId,
            majorVersion: majorVersion,
          );
          if (isPortalUser) {
            throw Exception("Portal Access");
          }
          throw Exception("Access Denied");
        }

        bool isSystem = isManager;

        List<int> allowedCompanyIds = [];
        if (majorVersion >= 13) {
          final companiesRes = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              ['company_ids'],
            ],
            'kwargs': {},
          });
          if (companiesRes is List && companiesRes.isNotEmpty) {
            allowedCompanyIds =
                (companiesRes[0]['company_ids'] as List?)?.cast<int>() ?? [];
          }
        }
        return SessionModel(
          sessionId: session.id,
          userName: session.userName,
          userLogin: session.userLogin.toString(),
          userId: session.userId,
          serverVersion: session.serverVersion,
          userLang: session.userLang,
          partnerId: session.partnerId,
          userTimezone: session.userTz,
          companyId: userData.isNotEmpty ? userData[0]['company_id'][0] : null,
          companyName: userData.isNotEmpty
              ? userData[0]['company_id'][1]
              : null,
          isSystem: isSystem,
          version: majorVersion,
          allowedCompanyIds: allowedCompanyIds,
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
