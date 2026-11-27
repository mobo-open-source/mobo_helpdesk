import 'dart:async';
import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/services/auth_service.dart';
import '../network/connectivity_service.dart';
import '../storage/password_security.dart';
import '../storage/storage_service.dart';
import 'database_expiry.dart';
import 'models/session_model.dart';
import '../storage/session_token_store.dart';

/// Central manager for handling Odoo sessions and company context across the application.
///
/// This class is responsible for:
/// - Managing the active [OdooClient] instance
/// - Caching and restoring [SessionModel]
/// - Handling company switching and multi-company context
/// - Persisting session data using SharedPreferences
/// - Automatic session refresh on authentication errors
/// - Providing safe RPC call wrappers (`callKwWithCompany`, `safeCallKw`, etc.)
///
/// It acts as a single source of truth for session state and ensures that all
/// RPC calls include the correct company context (`company_id` and `allowed_company_ids`).
class CompanySessionManager {
  static OdooClient? _client;
  static SessionModel? _cachedSession;

  static Future<bool>? _refreshInFlight;

  static DateTime? _lastAuthTime;

  static const Duration _sessionCacheValidDuration = Duration(minutes: 5);

  static Function(SessionModel)? _onSessionUpdated;

  static void registerSessionListener(Function(SessionModel) callback) {
    _onSessionUpdated = callback;
  }

  static bool _isAuthError(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('access denied') ||
        errorStr.contains('invalid session') ||
        errorStr.contains('session expired') ||
        errorStr.contains('authentication') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('403');
  }

  static Future<void> forceRefreshFromPrefs() async {
    _cachedSession = null;
    await getCurrentSession();
  }

  /// Returns the current active session, loading it from cache or SharedPreferences if needed.
  static Future<SessionModel?> getCurrentSession() async {
    if (_cachedSession != null) return _cachedSession;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return null;

    final String? sessionId = await SessionTokenStore.getActive();
    final int? userId = prefs.getInt('userId');
    final String? url = prefs.getString('url');

    if (sessionId == null ||
        sessionId.isEmpty ||
        userId == null ||
        url == null ||
        url.isEmpty) {
      return null;
    }

    final List<String> allowedRaw =
        prefs.getStringList('allowed_company_ids') ?? [];
    final List<int> allowedCompanyIds = allowedRaw
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e > 0)
        .toList();

    final session = SessionModel(
      sessionId: sessionId,
      userName: prefs.getString('userName'),
      userLogin: prefs.getString('userLogin'),
      userId: userId,
      serverVersion: prefs.getString('serverVersion'),
      userLang: prefs.getString('userLang'),
      partnerId: prefs.getInt('partnerId'),
      userTimezone: prefs.getString('userTimezone'),
      companyId: prefs.getInt('companyId'),
      companyName: prefs.getString('company_name'),
      isSystem: prefs.getBool('isSystem') ?? false,
      version: prefs.getInt('version'),
      allowedCompanyIds: allowedCompanyIds,
    );

    _cachedSession = session;

    ConnectivityService.instance.setCurrentServerUrl(url);
    return session;
  }

  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  static Future<void> notifySessionCreated() async {
    await forceRefreshFromPrefs();
    final session = await getCurrentSession();
    if (session != null) {
      _onSessionUpdated?.call(session);
    }
  }

  static Future<void> loginFromBrowserSession({
    required String sessionId,
    required String url,
    required String database,
    required Map<String, dynamic> sessionInfo,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('url', url);
    await prefs.setString('database', database);
    await SessionTokenStore.setActive(sessionId);

    await prefs.setInt('userId', sessionInfo['uid']);
    await prefs.setString('userName', sessionInfo['name']);
    await prefs.setString('userLogin', sessionInfo['login']);
    await prefs.setString(
      'serverVersion',
      sessionInfo['server_version'].toString(),
    );
    await prefs.setString(
      'userLang',
      sessionInfo['user_context']['lang'] ?? 'en_US',
    );
    await prefs.setString(
      'userTimezone',
      sessionInfo['user_context']['tz'] ?? 'UTC',
    );
    await prefs.setInt('partnerId', sessionInfo['partner_id']);
    await prefs.setInt('companyId', sessionInfo['company_id']);
    await prefs.setString('company_name', sessionInfo['company_name']);
    await prefs.setBool('isSystem', sessionInfo['is_system'] ?? false);

    final odooSession = OdooSession(
      id: sessionId,
      dbName: database,
      userId: sessionInfo['uid'],
      partnerId: sessionInfo['partner_id'],
      userLogin: sessionInfo['login'],
      userName: sessionInfo['name'],
      userLang: sessionInfo['user_context']['lang'] ?? 'en_US',
      userTz: sessionInfo['user_context']['tz'] ?? 'UTC',
      isSystem: sessionInfo['is_system'] ?? false,
      serverVersion: sessionInfo['server_version'].toString(),
      companyId: sessionInfo['company_id'],
      allowedCompanies: [],
    );

    _client?.close();
    _client = OdooClient(url, sessionId: odooSession);

    _cachedSession = SessionModel(
      sessionId: sessionId,
      userId: sessionInfo['uid'],
      userName: sessionInfo['name'],
      userLogin: sessionInfo['login'],
      serverVersion: odooSession.serverVersion,
      userLang: odooSession.userLang,
      partnerId: odooSession.partnerId,
      userTimezone: odooSession.userTz,
      companyId: odooSession.companyId,
      companyName: sessionInfo['company_name'],
      isSystem: odooSession.isSystem,
    );

    _lastAuthTime = DateTime.now();
    _onSessionUpdated?.call(_cachedSession!);
  }

  /// Performs full login with username/password and saves the session.
  ///
  /// Handles connectivity checks, authentication via [AuthService],
  /// and initializes the [OdooClient].
  static Future<bool> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
    totpSessionId,
    bool autoLoadCompanies = true,
  }) async {
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(normalizedUrl);
    } catch (e) {
      rethrow;
    }

    final authService = AuthService();
    final SessionModel? sessionModel = await authService.authenticateOdoo(
      url: normalizedUrl,
      database: database,
      username: userLogin,
      password: password,
      sessionId: totpSessionId,
    );

    if (sessionModel == null) return false;

    // Checked before anything is saved, so an expired database never leaves a
    // logged-in session behind.
    if (await DatabaseExpiry.isExpired(
      serverUrl: normalizedUrl,
      sessionId: sessionModel.sessionId,
    )) {
      throw const DatabaseExpiredException();
    }

    final storage = StorageService();
    await storage.saveSession(sessionModel);
    await storage.saveLoginState(
      isLoggedIn: true,
      database: database,
      url: normalizedUrl,
    );

    final prefs = await SharedPreferences.getInstance();
    final db = prefs.getString('database') ?? '';
    final sessionId = await SessionTokenStore.getActive() ?? '';
    final serverVersion = prefs.getString('serverVersion') ?? '';
    final userLang = prefs.getString('userLang') ?? '';
    final allowedCompaniesStringList =
        prefs.getStringList('allowedCompanies') ?? [];

    final allowedCompanies = allowedCompaniesStringList
        .map((jsonString) => Company.fromJson(jsonDecode(jsonString)))
        .toList();
    final session = OdooSession(
      id: sessionId,
      userId: prefs.getInt('userId') ?? 0,
      partnerId: prefs.getInt('partnerId') ?? 0,
      userLogin: prefs.getString('userLogin') ?? '',
      userName: prefs.getString('userName') ?? '',
      userLang: userLang,
      userTz: '',
      isSystem: prefs.getBool('isSystem') ?? false,
      dbName: db,
      serverVersion: serverVersion,
      companyId: prefs.getInt('companyId') ?? 1,
      allowedCompanies: allowedCompanies,
    );
    _client?.close();
    _client = null;

    _client = OdooClient(normalizedUrl, sessionId: session);
    _cachedSession = sessionModel;
    _lastAuthTime = DateTime.now();

    ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);
    _onSessionUpdated?.call(sessionModel);

    return true;
  }

  static Future<void> clearSessionCache() async {
    _cachedSession = null;
    _client?.close();
    _client = null;
    _lastAuthTime = null;
    _refreshInFlight = null;
  }

  static Future<bool> restoreSession({required int companyId}) async {
    if (companyId <= 0) return false;

    final session = await getCurrentSession();
    if (session == null) return false;

    final url = (await SharedPreferences.getInstance()).getString('url') ?? '';
    if (url.isEmpty) return false;

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(url);

      final updatedSession = SessionModel(
        sessionId: session.sessionId,
        userName: session.userName,
        userLogin: session.userLogin,
        userId: session.userId,
        serverVersion: session.serverVersion,
        userLang: session.userLang,
        partnerId: session.partnerId,
        userTimezone: session.userTimezone,
        companyId: companyId,
        companyName: session.companyName,
        isSystem: session.isSystem,
        version: session.version,
      );

      final prefs = await SharedPreferences.getInstance();
      final db = prefs.getString('database') ?? '';
      final sessionId = await SessionTokenStore.getActive() ?? '';
      final serverVersion = prefs.getString('serverVersion') ?? '';
      final userLang = prefs.getString('userLang') ?? '';
      final allowedCompaniesStringList =
          prefs.getStringList('allowedCompanies') ?? [];

      final allowedCompanies = allowedCompaniesStringList
          .map((jsonString) => Company.fromJson(jsonDecode(jsonString)))
          .toList();
      final odooSession = OdooSession(
        id: sessionId,
        userId: prefs.getInt('userId') ?? 0,
        partnerId: prefs.getInt('partnerId') ?? 0,
        userLogin: prefs.getString('userLogin') ?? '',
        userName: prefs.getString('userName') ?? '',
        userLang: userLang,
        userTz: '',
        isSystem: prefs.getBool('isSystem') ?? false,
        dbName: db,
        serverVersion: serverVersion,
        companyId: prefs.getInt('companyId') ?? 1,
        allowedCompanies: allowedCompanies,
      );

      final OdooClient client = OdooClient(url, sessionId: odooSession);
      await StorageService().saveSession(updatedSession);

      _client = client;
      _cachedSession = updatedSession;
      _lastAuthTime = DateTime.now();
      ConnectivityService.instance.setCurrentServerUrl(url);
      _onSessionUpdated?.call(updatedSession);

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateCompanySelection({
    required int companyId,
    required List<int> allowedCompanyIds,
  }) async {
    final session = await getCurrentSession();
    if (session == null) return;

    final updated = SessionModel(
      sessionId: session.sessionId,
      userName: session.userName,
      userLogin: session.userLogin,
      userId: session.userId,
      serverVersion: session.serverVersion,
      userLang: session.userLang,
      partnerId: session.partnerId,
      userTimezone: session.userTimezone,
      companyId: companyId,
      companyName: session.companyName,
      isSystem: session.isSystem,
      version: session.version,
    );

    await StorageService().saveSession(updated);
    _cachedSession = updated;
    _onSessionUpdated?.call(updated);
  }

  static Future<List<Map<String, dynamic>>> getAllowedCompaniesList() async {
    final client = await getClientEnsured();
    final session = await getCurrentSession();
    if (session == null || session.userId == null) return [];

    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          ['company_ids'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final companyIds =
            (result[0]['company_ids'] as List?)?.cast<int>() ?? [];
        if (companyIds.isEmpty) return [];

        final companies = await client.callKw({
          'model': 'res.company',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', companyIds],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'name'],
          },
        });

        if (companies is List) {
          return companies.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}

    return [];
  }

  static Future<int?> getSelectedCompanyId() async {
    final session = await getCurrentSession();
    if (session?.companyId != null) {
      return session!.companyId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('selected_company_id');
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> getSelectedAllowedCompanyIds() async {
    final session = await getCurrentSession();
    if (session != null && session.allowedCompanyIds.isNotEmpty) {
      return session.allowedCompanyIds;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('selected_allowed_company_ids') ?? [];
      return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e > 0).toList();
    } catch (_) {
      return [];
    }
  }

  /// Makes an RPC call with proper company context (`company_id` and `allowed_company_ids`).
  ///
  /// Automatically injects the current company and allowed companies into the context.
  static Future<dynamic> callKwWithCompany(
    Map<String, dynamic> payload, {
    int? companyId,
    List<int>? allowedCompanyIds,
  }) async {
    final map = Map<String, dynamic>.from(payload);

    Map<String, dynamic> kwargs = {};
    final rawKwargs = map['kwargs'];
    if (rawKwargs is Map) {
      kwargs = rawKwargs.map((key, value) => MapEntry(key.toString(), value));
    }

    Map<String, dynamic> ctx = {};
    final rawCtx = kwargs['context'];
    if (rawCtx is Map) {
      ctx = rawCtx.map((key, value) => MapEntry(key.toString(), value));
    }
    int? selectedCompany = companyId;
    List<int>? allowed = allowedCompanyIds;

    if (selectedCompany == null || allowed == null) {
      final session = await getCurrentSession();
      selectedCompany ??= session?.companyId ?? await getSelectedCompanyId();
      allowed ??= session?.allowedCompanyIds.isNotEmpty == true
          ? session!.allowedCompanyIds
          : await getSelectedAllowedCompanyIds();
    }

    if (selectedCompany != null) {
      ctx['company_id'] = selectedCompany;

      // The selected company goes FIRST, not appended. Odoo derives
      // `env.company` from `allowed_company_ids[0]` and ignores the
      // `company_id` context key entirely for that purpose. Appending meant
      // that for a user allowed [1, 3] who had selected 3, every call still
      // ran with `env.company` = 1 — so anything the server scopes to the
      // active company silently used the wrong one. `hr`'s
      // `res.users.employee_id`, for instance, is computed as the employee
      // whose `company_id == env.company.id`, which is why it read back as
      // `false` for a user who plainly has an employee record.
      final rest = {...allowed}..remove(selectedCompany);
      ctx['allowed_company_ids'] = <int>[selectedCompany, ...rest];
    }

    kwargs['context'] = ctx;
    map['kwargs'] = kwargs;

    return callWithSession((client) => client.callKw(map));
  }

  /// Concurrent callers (e.g. parallel RPCs hitting an expired session) share
  /// one refresh and all wait for its real result.
  static Future<bool> refreshSession() {
    return _refreshInFlight ??= _doRefreshSession().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<bool> _doRefreshSession() async {
    final current = await getCurrentSession();
    if (current == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final database = prefs.getString('database') ?? '';
    final url = prefs.getString('url') ?? '';
    final userLogin = current.userLogin ?? '';

    final password = await PasswordSecurity().getPassword(
      url: url,
      database: database,
      username: userLogin,
    );

    if (password == null || password.isEmpty) return false;

    return await loginAndSaveSession(
      serverUrl: url,
      database: database,
      userLogin: userLogin,
      password: password,
    );
  }

  static Future<void> initializeFromBrowserSession() async {
    final prefs = await SharedPreferences.getInstance();

    final String? rawSessionId = prefs.getString('odoo_session_id_raw');
    final String? url = prefs.getString('url');
    final String? database = prefs.getString('database');

    if (rawSessionId == null || rawSessionId.isEmpty) {
      return;
    }
    if (url == null || url.isEmpty) {
      return;
    }
    if (database == null || database.isEmpty) {
      return;
    }

    String cleanSessionId = rawSessionId.trim();
    if (cleanSessionId.contains(';')) {
      cleanSessionId = cleanSessionId.split(';').first.trim();
    }
    if (cleanSessionId.contains('=')) {
      cleanSessionId = cleanSessionId.split('=').last.trim();
    }

    final odooSession = OdooSession(
      id: cleanSessionId,
      dbName: database,
      userId: prefs.getInt('userId') ?? 0,
      partnerId: prefs.getInt('partnerId') ?? 0,
      userLogin: prefs.getString('userLogin') ?? '',
      userName: prefs.getString('userName') ?? '',
      userLang: prefs.getString('userLang') ?? 'en_US',
      userTz: prefs.getString('userTimezone') ?? 'UTC',
      isSystem: prefs.getBool('isSystem') ?? false,
      serverVersion: prefs.getString('serverVersion') ?? '',
      companyId: prefs.getInt('companyId') ?? 1,
      allowedCompanies: [],
    );

    _client?.close();
    _client = null;

    try {
      _client = OdooClient(url, sessionId: odooSession);

      _cachedSession = SessionModel(
        sessionId: cleanSessionId,
        userId: odooSession.userId,
        userName: odooSession.userName,
        userLogin: odooSession.userLogin,
        serverVersion: odooSession.serverVersion,
        userLang: odooSession.userLang,
        partnerId: odooSession.partnerId,
        userTimezone: odooSession.userTz,
        companyId: odooSession.companyId,
        companyName: prefs.getString('company_name') ?? 'Company',
        isSystem: odooSession.isSystem,
      );

      _lastAuthTime = DateTime.now();

      ConnectivityService.instance.setCurrentServerUrl(url);
      _onSessionUpdated?.call(_cachedSession!);
    } catch (e) {
      _client = null;
      _cachedSession = null;
    }
  }

  static Future<OdooClient> getClientEnsured() async {
    final session = await getCurrentSession();
    if (session == null) throw StateError('No session. Login required.');

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('url') ?? '';
    if (prefs.containsKey('odoo_session_id_raw')) {
      await initializeFromBrowserSession();
      if (_client != null) return _client!;
    }

    if (_client != null &&
        _cachedSession != null &&
        _lastAuthTime != null &&
        DateTime.now().difference(_lastAuthTime!) <
            _sessionCacheValidDuration) {
      return _client!;
    }

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(url);

      final prefs = await SharedPreferences.getInstance();
      final db = prefs.getString('database') ?? '';
      final sessionId = await SessionTokenStore.getActive() ?? '';
      final serverVersion = prefs.getString('serverVersion') ?? '';
      final userLang = prefs.getString('userLang') ?? '';
      final allowedCompaniesStringList =
          prefs.getStringList('allowedCompanies') ?? [];

      final allowedCompanies = allowedCompaniesStringList
          .map((jsonString) => Company.fromJson(jsonDecode(jsonString)))
          .toList();
      final session = OdooSession(
        id: sessionId,
        userId: prefs.getInt('userId') ?? 0,
        partnerId: prefs.getInt('partnerId') ?? 0,
        userLogin: prefs.getString('userLogin') ?? '',
        userName: prefs.getString('userName') ?? '',
        userLang: userLang,
        userTz: '',
        isSystem: prefs.getBool('isSystem') ?? false,
        dbName: db,
        serverVersion: serverVersion,
        companyId: prefs.getInt('companyId') ?? 1,
        allowedCompanies: allowedCompanies,
      );

      final client = OdooClient(url, sessionId: session);

      _client = client;
      _lastAuthTime = DateTime.now();
      return client;
    } on NoInternetException {
      final client = OdooClient(url);
      _client = client;
      return client;
    } on ServerUnreachableException {
      final client = OdooClient(url);
      _client = client;
      return client;
    }
  }

  static Future<T> callWithSession<T>(
    Future<T> Function(OdooClient client) action,
  ) async {
    final client = await getClientEnsured();
    try {
      return await action(client);
    } catch (e) {
      if (e is NoInternetException || e is ServerUnreachableException) rethrow;
      if (_isAuthError(e)) {
        final refreshed = await refreshSession();
        if (refreshed) {
          final newClient = await getClientEnsured();
          return await action(newClient);
        }
      }
      rethrow;
    }
  }

  static Future<dynamic> safeCallKw(Map<String, dynamic> payload) {
    return callKwWithCompany(payload);
  }

  static Future<dynamic> safeCallKwWithoutCompany(
    Map<String, dynamic> payload,
  ) {
    return callWithSession((client) => client.callKw(payload));
  }
}
