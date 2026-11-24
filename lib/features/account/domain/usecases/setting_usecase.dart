import '../repositories/setting_repo.dart';

/// Use case layer for application settings.
///
/// Acts as an intermediary between the presentation layer and [SettingRepo],
/// providing access to settings-related operations such as language,
/// currency, timezone management, and cache handling.
///
/// Responsibilities:
/// - Manage user language preferences
/// - Load currency and timezone data
/// - Handle cache size and clearing operations
class SettingUseCase {
  final SettingRepo settingRepo;

  SettingUseCase(this.settingRepo);

  Future<List<Map<String, dynamic>>> loadLanguages() {
    return settingRepo.loadLanguages();
  }

  Future<void> updateLanguage(String langCode) {
    return settingRepo.updateLanguage(langCode);
  }

  Future<List<Map<String, dynamic>>> loadCurrencies() {
    return settingRepo.loadCurrencies();
  }

  Future<List<Map<String, dynamic>>> loadTimezones() {
    return settingRepo.loadTimezones();
  }

  Future<void> updateTz(String tz) {
    return settingRepo.updateTz(tz);
  }

  Future<int> getCacheSize() => settingRepo.getCacheSize();

  Future<void> clearCache() => settingRepo.clearCache();
}
