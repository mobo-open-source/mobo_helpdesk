import 'dart:convert';

import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/session/database_expiry.dart';
import '../../../../core/session/models/session_model.dart';
import '../../../../core/storage/storage_service.dart';
import '../../domain/entities/database_entity.dart';
import '../../domain/repositories/login_repo.dart';
import '../datasources/login_local_datasource.dart';
import '../datasources/login_remote_datasource.dart';
import '../datasources/reset_password_remote_datasource.dart';
import '../models/database_model.dart';

/// Implementation of [LoginRepo] that handles authentication,
/// database retrieval, session management, and TOTP verification.
///
/// This class coordinates between remote data sources, local storage,
/// and session managers to perform login-related operations.
class LoginRepoImpl implements LoginRepo {
  LoginRemoteDatasource remoteDataSource = LoginRemoteDatasourceImpl();
  LoginLocalDatasource local = LoginLocalDatasourceImpl();
  ResetPasswordRemoteDataSource resetRemoteDataSource =
      ResetPasswordRemoteDataSourceImpl();

  /// Fetches the list of available databases from the given [url].
  ///
  /// Returns a list of [DatabaseEntity].
  @override
  Future<List<DatabaseEntity>> fetchDatabases(String url) async {
    final result = await remoteDataSource.fetchDatabaseList(url);

    return result.map((db) => DatabaseModel.fromJson(db)).toList();
  }

  /// Checks whether the given database is an Enterprise database.
  ///
  /// Requires valid [url], [database], [username], and [password].
  /// Returns `true` if the database is Enterprise, otherwise `false`.
  @override
  Future<bool> isEnterpriseDatabase(
    String url,
    String database,
    String username,
    String password,
  ) async {
    final versionInfo = await remoteDataSource.fetchVersionInfo(
      url,
      database,
      username,
      password,
    );

    return versionInfo;
  }

  /// Loads stored URL history grouped by the given [protocol].
  ///
  /// Example protocols: `http://`, `https://`.
  @override
  Future<Map<String, Map<String, String>>> loadUrlHistoryForProtocol(
    String protocol,
  ) {
    return local.loadUrlHistoryForProtocol(protocol: protocol);
  }

  /// Performs login using the provided credentials.
  ///
  /// Saves session and account details locally on success.
  /// If [isAddAccount] is false, previously stored accounts are cleared.
  ///
  /// Returns a [SessionModel] if login is successful, otherwise `null`.
  @override
  Future<SessionModel?> login({
    required String url,
    required String database,
    required String username,
    required String password,
    bool isAddAccount = false,
  }) async {
    final success = await CompanySessionManager.loginAndSaveSession(
      serverUrl: url,
      database: database,
      userLogin: username,
      password: password,
    );

    if (!success) return null;

    final session = await CompanySessionManager.getCurrentSession();
    if (session != null) {
      await local.saveUrlHistory(
        protocol: url.startsWith('https') ? 'https://' : 'http://',
        url: url,
        database: database,
        username: username.trim(),
      );

      if (!isAddAccount) {
        await StorageService().clearAccounts();
      }

      await StorageService().saveAccount({
        'userName': session.userName,
        'userLogin': session.userLogin,
        'userId': session.userId,
        'sessionId': session.sessionId,
        'serverVersion': session.serverVersion,
        'userLang': session.userLang,
        'partnerId': session.partnerId,
        'userTimezone': session.userTimezone,
        'companyId': session.companyId,
        'companyName': session.companyName,
        'isSystem': session.isSystem,
        'url': url,
        'database': database,
        'image': '',
      });
    }

    return session;
  }

  /// Sends a password reset request to the server.
  ///
  /// Requires [serverUrl], [database], and [email].
  /// Returns a response map containing status and message.
  @override
  Future<Map<String, dynamic>> requestPasswordReset({
    required String serverUrl,
    required String database,
    required String email,
  }) async {
    return await resetRemoteDataSource.sendResetPasswordEmail(
      serverUrl: serverUrl,
      database: database,
      email: email,
    );
  }

  /// Checks if the current session corresponds to an Enterprise instance.
  ///
  /// Uses stored session data from [SharedPreferences] and performs
  /// an RPC call to verify if the `web_enterprise` module is installed.
  ///
  /// Returns `true` if Enterprise features are available.
  Future<bool> checkEnterprise({
    required String serverUrl,
    required String sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final db = prefs.getString('database') ?? '';
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

    final client = OdooClient(serverUrl, sessionId: session);

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

    return count > 0;
  }

  /// Completes a TOTP (Two-Factor Authentication) login for [sessionId].
  ///
  /// The TOTP screen has already submitted the code and confirmed with the
  /// server that [sessionId] is authenticated as [username]. On success this:
  /// - Validates Enterprise access
  /// - Saves session and account details
  /// - Updates local preferences
  ///
  /// Returns a map containing:
  /// - `success`: boolean status
  /// - `message`: error message if any
  @override
  Future<Map<String, dynamic>> completeTotpLogin({
    required String sessionId,
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      final enterpriseCheck = await checkEnterprise(
        serverUrl: serverUrl,
        sessionId: sessionId,
      );
      if (!enterpriseCheck) {
        return {
          'success': false,
          'message':
              "Helpdesk module is only available in Odoo Enterprise Edition. Please select an Enterprise database or contact your administrator.",
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid code or authentication failed',
      };
    }

    final bool success;
    try {
      success = await CompanySessionManager.loginAndSaveSession(
        serverUrl: serverUrl,
        database: database,
        userLogin: username.trim(),
        password: password.trim(),
        totpSessionId: sessionId,
      );
    } on DatabaseExpiredException {
      return {'success': false, 'message': DatabaseExpiredException.message};
    }
    if (!success) {
      return {
        'success': false,
        'message': 'Invalid code or authentication failed',
      };
    }
    final session = await CompanySessionManager.getCurrentSession();
    await StorageService().saveAccount({
      'userName': session?.userName,
      'userLogin': session?.userLogin,
      'userId': session?.userId,
      'sessionId': session?.sessionId,
      'serverVersion': session?.serverVersion,
      'userLang': session?.userLang,
      'partnerId': session?.partnerId,
      'userTimezone': session?.userTimezone,
      'companyId': session?.companyId,
      'companyName': session?.companyName,
      'isSystem': session?.isSystem,
      'url': serverUrl,
      'database': database,
      'image': '',
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('logoutAction');

    await prefs.setString('sessionId', sessionId);
    await prefs.setString('username', username);
    await prefs.setString('url', serverUrl);
    await prefs.setString('database', database);
    await prefs.setBool('logoutAction', false);
    await prefs.setBool('isLoggedIn', true);

    await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
    return {'success': true, 'message': ''};
  }
}
