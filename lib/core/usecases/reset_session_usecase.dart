import 'package:shared_preferences/shared_preferences.dart';

import '../session/company_session_manager.dart';
import '../storage/storage_service.dart';
import '../utils/odoo_field_resolver.dart';
import '../storage/session_token_store.dart';

/// UseCase responsible for resetting the user's session while preserving essential app settings.
///
/// This is typically used during **logout** to clear sensitive session data
/// without losing user preferences such as:
/// - URL history
/// - Onboarding status (`hasSeenGetStarted`)
/// - Biometric authentication preference
///
/// The use case ensures a clean logout by:
/// 1. Preserving non-sensitive user preferences
/// 2. Clearing all other SharedPreferences data
/// 3. Removing saved multi-accounts
/// 4. Clearing the active Odoo session cache and client
class ResetSessionUseCase {
  /// Executes the session reset process.
  ///
  /// This method:
  /// - Saves important user preferences (URL history, onboarding flag, biometric setting)
  /// - Clears all SharedPreferences data
  /// - Restores the preserved preferences
  /// - Clears saved accounts via [StorageService]
  /// - Clears the Odoo session cache and client via [CompanySessionManager]
  ///
  /// After calling this, the user will be fully logged out and redirected to the login screen.
  Future<void> execute() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> urlHistory = prefs.getStringList('urlHistory') ?? [];
    bool hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;
    bool biometricEnabled = prefs.getBool('biometricEnabled') ?? false;

    await prefs.clear();

    await prefs.setStringList('urlHistory', urlHistory);
    await prefs.setBool('hasSeenGetStarted', hasSeenGetStarted);
    await prefs.setBool('biometricEnabled', biometricEnabled);

    await StorageService().clearAccounts();
    await SessionTokenStore.clearAll();

    await CompanySessionManager.clearSessionCache();
    OdooFieldResolver.clearCache();
  }
}
