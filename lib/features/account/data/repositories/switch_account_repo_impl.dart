import 'package:mobo_helpdesk/features/account/domain/repositories/switch_account_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/session/models/session_model.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/utils/odoo_field_resolver.dart';

/// Repository implementation responsible for switching between user accounts.
///
/// Handles:
/// - Updating stored session data
/// - Persisting selected user credentials in local storage
/// - Clearing and refreshing company session cache
class SwitchAccountRepoImpl implements SwitchAccountRepo {
  SwitchAccountRepoImpl();

  /// Switches the current logged-in user to a different account.
  ///
  /// Steps performed:
  /// - Reads stored preferences (version, allowed companies)
  /// - Builds and saves a new [SessionModel]
  /// - Updates persisted login-related values
  /// - Clears cached session data
  /// - Reloads current session
  ///
  /// [user] contains the selected account details from UI or API.
  @override
  Future<void> switchAccount(Map<String, dynamic> user) async {
    final url = user['url'] ?? '';
    final database = user['database'] ?? '';
    final sessionId = user['sessionId'] ?? '';
    final userId = user['userId'] ?? 0;
    final serverVersion = user['serverVersion'] ?? '';

    // Standardize URL
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    final regExp = RegExp(r'^(\d+)');
    final match = regExp.firstMatch(serverVersion);
    final int majorVersion = match != null ? int.parse(match.group(1)!) : 18;

    final dummySession = OdooSession(
      id: sessionId,
      userId: userId,
      partnerId: user['partnerId'] ?? 0,
      userLogin: user['userLogin'] ?? '',
      userName: user['userName'] ?? '',
      userLang: user['userLang'] ?? 'en_US',
      userTz: user['userTimezone'] ?? 'UTC',
      isSystem: user['isSystem'] ?? false,
      dbName: database,
      serverVersion: serverVersion,
      companyId: user['companyId'] ?? 1,
      allowedCompanies: [],
    );

    final client = OdooClient(normalizedUrl, sessionId: dummySession);

    bool isManager = false;
    bool isUser = false;
    bool isBaseSystem = false;

    // Odoo 18+ takes the user id as well; older releases check the caller.
    Future<bool> hasGroup(String group) async {
      final result = await client
          .callKw({
            'model': 'res.users',
            'method': 'has_group',
            'args': majorVersion >= 18 ? [userId, group] : [group],
            'kwargs': {},
          })
          // Bounded so an unreachable server fails the switch instead of
          // leaving it waiting on the socket.
          .timeout(const Duration(seconds: 15));
      return result == true;
    }

    try {
      // Independent checks, asked together rather than one after the other.
      final results = await Future.wait([
        hasGroup('helpdesk.group_helpdesk_manager'),
        hasGroup('base.group_system'),
        hasGroup('helpdesk.group_helpdesk_user'),
      ]);
      isManager = results[0];
      isBaseSystem = results[1];
      isUser = results[2];
    } catch (e) {
      // If we cannot connect to Odoo server or session is invalid, deny switch
      throw Exception("Access Denied");
    } finally {
      client.close();
    }

    if (!isManager && !isUser && !isBaseSystem) {
      throw Exception("Access Denied");
    }

    final bool isSystem = isManager || isBaseSystem;

    final prefs = await SharedPreferences.getInstance();

    final version = prefs.getInt("version") ?? 0;

    // The new account's own allowed companies. Reading the shared preference
    // here would hand it the previous account's list, and every request the
    // new account makes would carry the wrong company context.
    final storedAllowed = user['allowed_company_ids'];
    final allowedRaw = storedAllowed is List
        ? storedAllowed.map((e) => e.toString()).toList()
        : <String>[];
    final allowedCompanyIds = allowedRaw
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e > 0)
        .toList();

    await StorageService().saveSession(
      SessionModel(
        sessionId: sessionId,
        userName: user['userName'],
        userLogin: user['userLogin'],
        userId: userId,
        serverVersion: serverVersion,
        userLang: user['userLang'],
        partnerId: user['partnerId'],
        userTimezone: user['userTimezone'],
        companyId: user['companyId'],
        companyName: user['companyName'],
        isSystem: isSystem,
        version: version,
        allowedCompanyIds: allowedCompanyIds,
      ),
    );

    await StorageService().saveAccount({
      'userName': user['userName'],
      'userLogin': user['userLogin'],
      'userId': userId,
      'sessionId': sessionId,
      'serverVersion': serverVersion,
      'userLang': user['userLang'],
      'partnerId': user['partnerId'],
      'userTimezone': user['userTimezone'],
      'companyId': user['companyId'],
      'companyName': user['companyName'],
      'isSystem': isSystem,
      'url': url,
      'database': database,
      'image': user['image'] ?? '',
    });

    await prefs.setString('userLogin', user['userLogin'].toString());
    await prefs.setString('url', url);
    await prefs.setString('database', database);
    await prefs.setInt('userId', userId);
    await prefs.setBool('isSystem', isSystem);

    // The company choice belongs to the account it was made in. Left in place,
    // the new account would start on the old one's selection and its first
    // lists would load empty until the company was corrected.
    await prefs.remove('selected_company_id');
    await prefs.remove('selected_allowed_company_ids');
    await prefs.remove('pending_company_id');
    await prefs.setStringList('allowed_company_ids', allowedRaw);

    await CompanySessionManager.clearSessionCache();
    OdooFieldResolver.clearCache();

    await CompanySessionManager.getCurrentSession();
  }
}
