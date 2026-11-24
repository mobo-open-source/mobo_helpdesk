import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for securely storing and retrieving Odoo user passwords.
///
/// This class uses [FlutterSecureStorage] to store passwords encrypted on the device.
/// Passwords are keyed using a combination of server URL, database name, and username
/// to support multiple Odoo instances and accounts.
///
/// **Security Note:**
/// - Passwords are stored only after successful login.
/// - The storage is cleared on logout (via `deleteAllPasswords`).
/// - On Android, default encrypted storage is used.
/// - On iOS, the keychain is configured to be accessible after first unlock on this device.
class PasswordSecurity {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static String _passwordKey(String url, String database, String username) {
    return 'odoo_pass_${url}_$database}_$username';
  }

  Future<String?> getPassword({
    required String url,
    required String database,
    required String username,
  }) async {
    final key = _passwordKey(url, database, username);
    return await _storage.read(key: key);
  }

  /// Deletes the password saved for a single account.
  ///
  /// Used when an account is removed from the device, so its credentials do not
  /// stay behind in secure storage.
  Future<void> deletePassword({
    required String url,
    required String database,
    required String username,
  }) async {
    final key = _passwordKey(url, database, username);
    await _storage.delete(key: key);
  }

  Future<void> deleteAllPasswords() async {
    await _storage.deleteAll();
  }
}
