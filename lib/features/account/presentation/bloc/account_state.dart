part of 'account_bloc.dart';

enum ConfigurationStatus { initial, loading, success, failure }

/// State class for [AccountBloc].
///
/// Represents the complete state of the Account feature including:
/// - Profile data
/// - Settings (language, currency, timezone)
/// - Biometric status
/// - Cache information
/// - Location data (country/state)
/// - UI status flags (loading, success, error, info)
class AccountState extends Equatable {
  final bool isLoading;
  final ProfileEntity? data;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> states;

  final ConfigurationStatus configurationStatus;
  final Map<String, String>? error;

  final List<Map<String, dynamic>> languages;
  final List<Map<String, dynamic>> currencies;
  final List<Map<String, dynamic>> timezones;

  final String selectedLanguage;
  final String selectedCurrency;
  final String selectedTimezone;

  final int cacheSize;

  final bool enabled;
  final String? message;
  final bool? isError;
  final bool? isSuccess;
  final bool? isInfo;

  final Uint8List? profileImageBytes;

  /// A profile/address/company write is in flight; the page shows a blocking
  /// dialog labelled [savingLabel] instead of replacing itself with a shimmer.
  final bool isSaving;
  final String savingLabel;

  final Map<String, dynamic>? selectedCountry;
  final int? selectedCountryId;
  final Map<String, dynamic>? selectedState;
  final int? selectedStateId;

  const AccountState({
    this.isLoading = false,
    this.data,
    this.countries = const [],
    this.states = const [],
    this.configurationStatus = ConfigurationStatus.initial,
    this.error,
    this.languages = const [],
    this.currencies = const [],
    this.timezones = const [],
    this.selectedLanguage = "English (US)",
    this.selectedCurrency = "United States dollar",
    this.selectedTimezone = "Asia/Kolkata",
    this.cacheSize = 0,
    this.enabled = false,
    this.message,
    this.isError,
    this.isInfo,
    this.isSuccess,
    this.profileImageBytes,
    this.isSaving = false,
    this.savingLabel = 'Saving Changes',
    this.selectedCountry,
    this.selectedCountryId,
    this.selectedState,
    this.selectedStateId,
  });

  AccountState copyWith({
    bool? isLoading,
    ProfileEntity? data,
    List<Map<String, dynamic>>? countries,
    List<Map<String, dynamic>>? states,
    ConfigurationStatus? configurationStatus,
    Map<String, String>? error,
    List<Map<String, dynamic>>? languages,
    List<Map<String, dynamic>>? currencies,
    List<Map<String, dynamic>>? timezones,
    String? selectedLanguage,
    String? selectedCurrency,
    String? selectedTimezone,
    int? cacheSize,
    bool? enabled,
    String? message,
    bool? isError,
    bool? isInfo,
    bool? isSuccess,
    bool clearMessage = false,

    Uint8List? profileImageBytes,
    bool clearProfileImage = false,
    bool? isSaving,
    String? savingLabel,
    Map<String, dynamic>? selectedCountry,
    int? selectedCountryId,
    Map<String, dynamic>? selectedState,
    int? selectedStateId,
  }) {
    return AccountState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      countries: countries ?? this.countries,
      states: states ?? this.states,
      configurationStatus: configurationStatus ?? this.configurationStatus,
      error: error,
      languages: languages ?? this.languages,
      currencies: currencies ?? this.currencies,
      timezones: timezones ?? this.timezones,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      selectedTimezone: selectedTimezone ?? this.selectedTimezone,
      cacheSize: cacheSize ?? this.cacheSize,
      enabled: enabled ?? this.enabled,
      message: clearMessage ? null : message ?? this.message,
      isError: isError ?? this.isError,
      isInfo: isInfo ?? this.isInfo,
      isSuccess: isSuccess ?? this.isSuccess,
      profileImageBytes: clearProfileImage
          ? null
          : profileImageBytes ?? this.profileImageBytes,
      isSaving: isSaving ?? this.isSaving,
      savingLabel: savingLabel ?? this.savingLabel,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      selectedCountryId: selectedCountryId ?? this.selectedCountryId,
      selectedState: selectedState ?? this.selectedState,
      selectedStateId: selectedStateId ?? this.selectedStateId,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    data,
    countries,
    states,
    configurationStatus,
    error,
    languages,
    currencies,
    timezones,
    selectedLanguage,
    selectedCurrency,
    selectedTimezone,
    cacheSize,
    enabled,
    message,
    isError,
    isInfo,
    isSuccess,
    profileImageBytes,
    isSaving,
    savingLabel,
    selectedCountry,
    selectedCountryId,
    selectedState,
    selectedStateId,
  ];
}
