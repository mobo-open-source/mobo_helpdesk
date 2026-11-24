import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobo_helpdesk/features/account/domain/usecases/switch_account_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/events/profile_refresh_bus.dart';
import '../../../../core/storage/storage_service.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/usecases/biometric_usecase.dart';
import '../../domain/usecases/profile_usecase.dart';
import '../../domain/usecases/setting_usecase.dart';

part 'account_event.dart';

part 'account_state.dart';

/// BLoC responsible for managing account-related features.
///
/// Handles all account operations including:
/// - Profile loading and updates
/// - Account switching
/// - Settings (language, currency, timezone, cache)
/// - Biometric authentication
/// - Image picking for profile updates
///
/// Acts as the central state manager for the Account feature
/// and coordinates between UI and domain use cases.
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final ProfileUseCase profileUseCase;
  final SwitchAccountUseCase switchAccountUseCase;
  final SettingUseCase settingUseCase;
  final BiometricUseCase biometricUseCase;

  AccountBloc(
    this.profileUseCase,
    this.switchAccountUseCase,
    this.settingUseCase,
    this.biometricUseCase,
  ) : super(AccountState()) {
    on<ProfileDataLoad>(_loadProfileData);
    on<SwitchAccountEvent>(_onSwitchAccount);

    on<LoadSettingsEvent>(_loadSettings);
    on<UpdateLanguageEvent>(_updateLanguage);
    on<UpdateCurrencyEvent>(_updateCurrency);
    on<UpdateTimezoneEvent>(_updateTimezone);

    on<LoadCacheSize>(_loadCacheSize);
    on<ClearCacheEvent>(_clearCache);

    on<EnableBiometric>(_onEnableBiometric);
    on<DisableBiometric>(_onDisableBiometric);
    on<SetBiometricInitial>(_onSetBiometricInitial);

    on<PickImageEvent>(_onPickImage);

    on<UpdateCountryEvent>(_onUpdateCountry);
    on<UpdateStateEvent>(_onUpdateState);
    on<UpdateProfile>(_onUpdateProfile);
    on<UpdateRelatedCompany>(_onUpdateRelatedCompany);
    on<ClearPickedImage>(
      (event, emit) => emit(state.copyWith(clearProfileImage: true)),
    );
    on<ClearAccountMessage>((event, emit) {
      emit(state.copyWith(clearMessage: true));
    });
  }

  /// Loads user profile and related country/state data.
  Future<void> _loadProfileData(
    ProfileDataLoad event,
    Emitter<AccountState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final profileData = await profileUseCase.loadProfile();
      await _syncStoredAccount(profileData);
      final countryData = await profileUseCase.loadCountry();

      final selectedCountry =
          profileData.countryId is List && profileData.countryId.isNotEmpty
          ? {
              'id': profileData.countryId[0],
              'name': profileData.countryId.length > 1
                  ? profileData.countryId[1]
                  : '',
            }
          : null;

      final selectedState =
          profileData.stateId is List && profileData.stateId.isNotEmpty
          ? {
              'id': profileData.stateId[0],
              'name': profileData.stateId.length > 1
                  ? profileData.stateId[1]
                  : '',
            }
          : null;

      emit(
        state.copyWith(
          isLoading: false,
          data: profileData,
          countries: countryData,
          selectedCountry: selectedCountry,
          selectedCountryId: selectedCountry?['id'] as int?,
          selectedState: selectedState,
          selectedStateId: selectedState?['id'] as int?,
        ),
      );
      if (selectedCountry != null && selectedCountry['id'] != null) {
        final stateData = await profileUseCase.loadState(selectedCountry['id']);
        emit(
          state.copyWith(
            states: stateData,
            selectedState: null,
            selectedStateId: null,
          ),
        );
      }
    } catch (e) {
      if (e is Map<String, String>) {
        emit(state.copyWith(isLoading: false, error: e));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: {'title': 'Error', 'description': e.toString()},
          ),
        );
      }
    }
  }

  /// Switches account and reloads profile data.
  Future<void> _onSwitchAccount(
    SwitchAccountEvent event,
    Emitter<AccountState> emit,
  ) async {
    try {
      emit(state.copyWith(configurationStatus: ConfigurationStatus.loading));

      // Bounded: an unreachable server otherwise leaves the "Switching
      // Account..." dialog up with nothing to dismiss it.
      await switchAccountUseCase
          .switchAccount(event.user)
          .timeout(const Duration(seconds: 30));

      // No profile reload here: success restarts the app, and the rebuilt
      // AccountBloc loads the new account's profile itself.
      emit(state.copyWith(configurationStatus: ConfigurationStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          configurationStatus: ConfigurationStatus.failure,
          message: e.toString(),
          isError: true,
        ),
      );
    }
  }

  /// Loads application settings (language, currency, timezone).
  Future<void> _loadSettings(
    LoadSettingsEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(
      state.copyWith(
        configurationStatus: ConfigurationStatus.loading,
        isLoading: true,
        error: null,
      ),
    );

    try {
      final lang = await settingUseCase.loadLanguages();
      final curr = await settingUseCase.loadCurrencies();
      final tz = await settingUseCase.loadTimezones();

      emit(
        state.copyWith(
          languages: List<Map<String, dynamic>>.from(lang),
          currencies: List<Map<String, dynamic>>.from(curr),
          timezones: List<Map<String, dynamic>>.from(tz),
          configurationStatus: ConfigurationStatus.success,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          configurationStatus: ConfigurationStatus.failure,
          isLoading: false,
          error: {'title': 'Error', 'description': "Unable to fetch"},
        ),
      );
    }
  }

  /// Updates selected language.
  Future<void> _updateLanguage(
    UpdateLanguageEvent event,
    Emitter<AccountState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await settingUseCase.updateLanguage(event.code);

      await prefs.setString('language', event.language);

      emit(
        state.copyWith(
          selectedLanguage: event.language,
          message: 'Language updated successfully',
          isSuccess: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(message: e.toString(), isError: true));
    }
  }

  /// Updates selected currency.
  Future<void> _updateCurrency(
    UpdateCurrencyEvent event,
    Emitter<AccountState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString('currency', event.currency);

      emit(
        state.copyWith(
          selectedCurrency: event.currency,
          message: 'Currency updated successfully',
          isSuccess: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(message: e.toString(), isError: true));
    }
  }

  /// Updates selected timezone.
  Future<void> _updateTimezone(
    UpdateTimezoneEvent event,
    Emitter<AccountState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await settingUseCase.updateTz(event.timezone);

      await prefs.setString('timezone', event.timezone);

      emit(
        state.copyWith(
          selectedTimezone: event.timezone,
          message: 'Timezone updated successfully',
          isSuccess: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(message: e.toString(), isError: true));
    }
  }

  /// Loads cache size information.
  Future<void> _loadCacheSize(
    LoadCacheSize event,
    Emitter<AccountState> emit,
  ) async {
    final size = await settingUseCase.getCacheSize();
    emit(state.copyWith(cacheSize: size));
  }

  /// Clears application cache.
  Future<void> _clearCache(
    ClearCacheEvent event,
    Emitter<AccountState> emit,
  ) async {
    await settingUseCase.clearCache();
    final size = await settingUseCase.getCacheSize();
    emit(state.copyWith(cacheSize: size));
  }

  /// Enables biometric authentication after verification.
  Future<void> _onEnableBiometric(
    EnableBiometric event,
    Emitter<AccountState> emit,
  ) async {
    try {
      final isSupported = await biometricUseCase.isSupported();
      if (!isSupported) {
        emit(
          state.copyWith(
            enabled: false,
            message:
                'Biometric authentication not supported or no biometrics enrolled.',
            isInfo: true,
          ),
        );
        return;
      }
      final isWeek = await biometricUseCase.isWeekAuth();
      if (isWeek) {
        emit(
          state.copyWith(
            enabled: false,
            message:
                'Biometric not supported on this device (face/fingerprint unlock not allowed).',
            isInfo: true,
          ),
        );
      } else {
        final isEnabled = await biometricUseCase.enable();
        if (isEnabled) {
          emit(
            state.copyWith(
              enabled: true,
              message: 'Biometric authentication enabled.',
              isSuccess: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              enabled: false,
              message: 'Authentication failed.',
              isError: true,
            ),
          );
        }
      }
    } catch (_) {
      emit(
        state.copyWith(
          enabled: false,
          message: 'Authentication error occurred.',
          isError: true,
        ),
      );
    }
  }

  /// Disables biometric authentication.
  Future<void> _onDisableBiometric(
    DisableBiometric event,
    Emitter<AccountState> emit,
  ) async {
    await biometricUseCase.disable();
    emit(
      state.copyWith(
        enabled: false,
        message: 'Biometric authentication disabled.',
        isInfo: true,
      ),
    );
  }

  /// Initializes biometric state from stored value.
  Future<void> _onSetBiometricInitial(
    SetBiometricInitial event,
    Emitter<AccountState> emit,
  ) async {
    emit(state.copyWith(enabled: event.enabled));
  }

  /// Picks an image for profile update.
  Future<void> _onPickImage(
    PickImageEvent event,
    Emitter<AccountState> emit,
  ) async {
    try {
      final bytes = await profileUseCase.imagePick(event.source);

      if (bytes != null) {
        emit(state.copyWith(profileImageBytes: bytes));
      }
    } catch (e) {
      emit(state.copyWith(message: "Failed to pick image", isError: true));
    }
  }

  /// Updates selected country and reloads states.
  Future<void> _onUpdateCountry(
    UpdateCountryEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedCountry: event.country,
        selectedCountryId: event.country?['id'],
        selectedState: null,
        selectedStateId: null,
        isLoading: true,
        message: null,
      ),
    );

    try {
      final stateData = await profileUseCase.loadState(
        event.country?['id'] ?? 0,
      );
      emit(
        state.copyWith(
          states: stateData,
          selectedState: null,
          selectedStateId: null,
          isLoading: false,
          message: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          states: [],
          isLoading: false,
          message: 'Failed to load states',
          isError: true,
        ),
      );
    }
  }

  /// Updates selected state.
  Future<void> _onUpdateState(
    UpdateStateEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedState: event.state,
        selectedStateId: event.state?['id'],
        message: null,
      ),
    );
  }

  /// Updates user profile information.
  ///
  /// Only the values the page sent are written (it sends what changed), and the
  /// page stays on screen behind a blocking dialog rather than swapping to a
  /// shimmer.
  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<AccountState> emit,
  ) async {
    final isAddress = event.isAddress ?? false;
    try {
      emit(
        state.copyWith(
          isSaving: true,
          savingLabel: isAddress ? 'Updating Address' : 'Saving Changes',
          message: null,
        ),
      );

      final partnerId = event.partnerId ?? state.data?.partnerId;
      if (partnerId == null) throw Exception('Profile is not loaded yet');

      final result = await profileUseCase.updateUserAddress({
        if (!isAddress) ...{
          if (event.name != null) 'name': event.name,
          if (event.mail != null) 'email': event.mail,
          // Canonical keys: the datasource routes them to this server's field.
          if (event.phone != null) 'phone': event.phone,
          if (event.mobile != null) 'mobile': event.mobile,
          if (event.website != null) 'website': event.website,
          if (event.function != null) 'function': event.function,
          if (event.image != null) 'image_1920': event.image,
        } else ...{
          // The whole address is one payload; an empty value clears the field.
          'street': event.street1,
          'street2': _orFalse(event.street2),
          'city': _orFalse(event.city),
          'zip': _orFalse(event.zip),
          'country_id': event.countryId ?? false,
          'state_id': event.stateId ?? false,
        },
      }, partnerId);
      await _finishSave(
        emit,
        result,
        isAddress
            ? 'Address updated successfully'
            : 'Profile updated successfully',
        failure: isAddress
            ? 'Failed to update address'
            : 'Failed to save changes',
        affectsApp: !isAddress,
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          message: e.toString(),
          isError: true,
          isSuccess: false,
        ),
      );
    }
  }

  /// Sets or clears the partner's related company.
  Future<void> _onUpdateRelatedCompany(
    UpdateRelatedCompany event,
    Emitter<AccountState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isSaving: true,
          savingLabel: 'Updating Related Company',
          message: null,
        ),
      );
      final partnerId = event.partnerId ?? state.data?.partnerId;
      if (partnerId == null) throw Exception('Profile is not loaded yet');

      final result = await profileUseCase.updateUserAddress({
        'parent_id': event.companyId ?? false,
      }, partnerId);
      await _finishSave(
        emit,
        result,
        'Related Company updated',
        failure: 'Failed to update related company',
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          message: e.toString(),
          isError: true,
          isSuccess: false,
        ),
      );
    }
  }

  /// Reloads the profile after a write and reports the outcome.
  ///
  /// [affectsApp] is true when the write changed something shown outside this
  /// page (name, email, photo), so the rest of the app is told to redraw.
  Future<void> _finishSave(
    Emitter<AccountState> emit,
    Map<String, dynamic> result,
    String success, {
    required String failure,
    bool affectsApp = false,
  }) async {
    if (result['success'] == true) {
      final profileData = await profileUseCase.loadProfile();
      await _syncStoredAccount(profileData);
      if (affectsApp) {
        ProfileRefreshBus.notify(
          ProfileUpdate(
            name: profileData.name,
            mail: profileData.mail,
            image: profileData.image,
          ),
        );
      }
      emit(
        state.copyWith(
          isSaving: false,
          data: profileData,
          clearProfileImage: true,
          message: success,
          isSuccess: true,
          isError: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isSaving: false,
          message: result['error'] ?? failure,
          isError: true,
          isSuccess: false,
        ),
      );
    }
  }

  /// Writes the profile's name and photo into the stored account entry, which
  /// is what the Switch Accounts list reads.
  Future<void> _syncStoredAccount(ProfileEntity profile) async {
    try {
      await StorageService().updateCurrentAccountDisplay(
        name: profile.name,
        image: profile.image,
      );
    } catch (_) {
      // Display data only; never fails the load or save it rides on.
    }
  }

  Object _orFalse(String? value) =>
      (value == null || value.trim().isEmpty) ? false : value.trim();
}
