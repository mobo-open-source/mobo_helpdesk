/// Repository contract for application settings.
///
/// Defines operations related to user preferences and system settings
/// such as language, currency, timezone, and cache management.
abstract class SettingRepo {
  Future<List<Map<String, dynamic>>> loadLanguages();

  Future<void> updateLanguage(String langCode);

  Future<List<Map<String, dynamic>>> loadCurrencies();

  Future<List<Map<String, dynamic>>> loadTimezones();

  Future<void> updateTz(String tz);

  Future<int> getCacheSize();

  Future<void> clearCache();
}
