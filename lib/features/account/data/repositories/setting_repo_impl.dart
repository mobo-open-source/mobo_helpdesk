import '../../domain/repositories/setting_repo.dart';
import '../datasources/setting_remote_datasource.dart';

/// Repository implementation for application settings.
///
/// Acts as a bridge between the domain layer and
/// [SettingRemoteDatasource].
///
/// Responsibilities:
/// - Fetch languages, currencies, and timezones
/// - Update user preferences (language, timezone)
/// - Manage cache operations (size & clearing)
class SettingRepoImpl implements SettingRepo {
  final SettingRemoteDatasource settingRemoteDatasource;

  SettingRepoImpl(this.settingRemoteDatasource);

  /// Loads available languages.
  @override
  Future<List<Map<String, dynamic>>> loadLanguages() async {
    return await settingRemoteDatasource.loadLanguages();
  }

  /// Updates selected language for the user.
  @override
  Future<void> updateLanguage(String langCode) {
    return settingRemoteDatasource.updateLanguage(langCode);
  }

  /// Loads available currencies.
  @override
  Future<List<Map<String, dynamic>>> loadCurrencies() async {
    return await settingRemoteDatasource.loadCurrencies();
  }

  /// Loads available timezones.
  @override
  Future<List<Map<String, dynamic>>> loadTimezones() async {
    return await settingRemoteDatasource.loadTimezones();
  }

  /// Updates selected timezone for the user.
  @override
  Future<void> updateTz(String tz) {
    return settingRemoteDatasource.updateTz(tz);
  }

  /// Returns total cache size in bytes.
  @override
  Future<int> getCacheSize() async {
    return await settingRemoteDatasource.getCacheSize();
  }

  /// Clears application cache.
  @override
  Future<void> clearCache() async {
    return await settingRemoteDatasource.clearCache();
  }
}
