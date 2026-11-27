import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/models/session_model.dart';
import 'session_token_store.dart';

/// Service responsible for persisting session data and login state using SharedPreferences.
///
/// This class handles:
/// - Saving and loading the current [SessionModel]
/// - Storing basic login status (isLoggedIn, database, url)
/// - Managing multiple logged-in accounts (for account switching)
///
/// All sensitive data like passwords are stored separately using [PasswordSecurity].
class StorageService {
  /// Saves the current Odoo session details to SharedPreferences.
  ///
  /// This includes user information, session ID, company context, and allowed companies.
  /// Used after successful login or when company context changes.
  Future<void> saveSession(SessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', session.userName ?? '');
    await prefs.setString('userLogin', session.userLogin ?? '');
    await prefs.setInt('userId', session.userId ?? 0);
    await SessionTokenStore.setActive(session.sessionId);
    await prefs.setString('serverVersion', session.serverVersion ?? '');
    await prefs.setString('userLang', session.userLang ?? '');
    await prefs.setInt('partnerId', session.partnerId ?? 0);
    await prefs.setString('userTimezone', session.userTimezone ?? '');
    await prefs.setInt('companyId', session.companyId ?? 1);
    await prefs.setString('company_name', session.companyName ?? '');
    await prefs.setBool('isSystem', session.isSystem);
    await prefs.setInt('version', session.version ?? 0);
    await prefs.setStringList(
      'allowed_company_ids',
      session.allowedCompanyIds.map((e) => e.toString()).toList(),
    );
  }

  Future<String?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userLang');
  }

  Future<void> saveLoginState({
    required bool isLoggedIn,
    required String database,
    required String url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('database', database);
    await prefs.setString('url', url);
  }

  Future<Map<String, dynamic>> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
      'useLocalAuth': prefs.getBool('useLocalAuth') ?? false,
      'database': prefs.getString('database') ?? '',
      'url': prefs.getString('url') ?? '',
    };
  }

  static const _accountsKey = 'loggedInAccounts';

  /// Saves or updates an account in the multi-account list.
  ///
  /// If an account with the same (userLogin + url + database) already exists,
  /// it will be replaced. Useful for account switching features.
  Future<void> saveAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();

    accounts.removeWhere(
      (a) =>
          a['userLogin'] == account['userLogin'] &&
          a['url'] == account['url'] &&
          a['database'] == account['database'],
    );

    if (!account.containsKey('image')) {
      account['image'] = '';
    }

    if (account['allowed_company_ids'] == null) {
      account['allowed_company_ids'] = <int>[];
    }
    if (account['allowed_companies'] == null) {
      account['allowed_companies'] = <Map<String, dynamic>>[];
    }

    // The session id is a bearer credential: it goes to secure storage and is
    // never written into the plaintext accounts list.
    final sid = account.remove('sessionId');
    if (sid != null && sid.toString().isNotEmpty) {
      await SessionTokenStore.setAccount(
        account['url'],
        account['database'],
        account['userLogin'],
        sid.toString(),
      );
    }

    accounts.add(account);

    await prefs.setString(_accountsKey, _encodeAccounts(accounts));
  }

  /// Brings the signed-in account's stored display name and photo in line with
  /// its profile, so the Switch Accounts list and the session keep showing
  /// what was last edited instead of what was saved at login.
  ///
  /// Matched on url + database + user id. Null or empty [name] / [image] leave
  /// that value as it was, so a failed or partial read cannot blank an entry.
  Future<void> updateCurrentAccountDisplay({
    String? name,
    String? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('url') ?? '';
    final database = prefs.getString('database') ?? '';
    final userId = prefs.getInt('userId');
    if (userId == null) return;

    final hasName = name != null && name.isNotEmpty;
    final hasImage = image != null && image.isNotEmpty;
    if (!hasName && !hasImage) return;

    if (hasName) await prefs.setString('userName', name);

    final accounts = await getAccounts();
    var changed = false;
    for (final account in accounts) {
      final sameUser = '${account['userId']}' == '$userId';
      if (sameUser &&
          (account['url'] ?? '').toString() == url &&
          (account['database'] ?? '').toString() == database) {
        if (hasName) account['userName'] = name;
        if (hasImage) account['image'] = image;
        changed = true;
      }
    }
    if (changed) await prefs.setString(_accountsKey, _encodeAccounts(accounts));
  }

  /// Serializes the accounts list without session ids, which live only in
  /// secure storage.
  String _encodeAccounts(List<Map<String, dynamic>> accounts) => jsonEncode(
    accounts
        .map((a) => Map<String, dynamic>.of(a)..remove('sessionId'))
        .toList(),
  );

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson == null) return [];
    final decoded = jsonDecode(accountsJson) as List<dynamic>;
    final accounts = decoded.cast<Map<String, dynamic>>();
    for (final a in accounts) {
      a['sessionId'] =
          await SessionTokenStore.getAccount(
            a['url'],
            a['database'],
            a['userLogin'],
          ) ??
          '';
    }
    return accounts;
  }

  Future<void> clearAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
    await SessionTokenStore.clearAccountTokens();
  }

  /// Removes a saved account matching the (url + database + userLogin) triple.
  ///
  /// This is the same identity [saveAccount] dedupes on, so it removes an entry
  /// even when the stored name or user id differs from what is displayed (older
  /// builds saved the id as a string).
  Future<void> removeAccountByIdentity({
    required String url,
    required String database,
    required String userLogin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    await SessionTokenStore.removeAccount(url, database, userLogin);

    accounts.removeWhere(
      (a) =>
          (a['userLogin'] ?? '').toString() == userLogin &&
          (a['url'] ?? '').toString() == url &&
          (a['database'] ?? '').toString() == database,
    );

    await prefs.setString(_accountsKey, _encodeAccounts(accounts));
  }

  Future<void> removeAccount({
    required String userLogin,
    required String userName,
    required int userId,
    required String url,
    required String database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    await SessionTokenStore.removeAccount(url, database, userLogin);

    accounts.removeWhere(
      (a) =>
          a['userLogin'] == userLogin &&
          a['userName'] == userName &&
          a['userId'] == userId &&
          a['url'] == url &&
          a['database'] == database,
    );

    await prefs.setString(_accountsKey, _encodeAccounts(accounts));
  }
}
