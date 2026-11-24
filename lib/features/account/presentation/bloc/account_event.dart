part of 'account_bloc.dart';

/// Base class for all Account-related events.
///
/// Defines all possible user actions and triggers that can be
/// dispatched to [AccountBloc] for state management.
abstract class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load user profile data.
class ProfileDataLoad extends AccountEvent {}

/// Event to switch between user accounts.
class SwitchAccountEvent extends AccountEvent {
  final Map<String, dynamic> user;

  const SwitchAccountEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Event to load application settings (language, currency, timezone).
class LoadSettingsEvent extends AccountEvent {}

/// Event to update selected language.
class UpdateLanguageEvent extends AccountEvent {
  final String code;
  final String language;

  const UpdateLanguageEvent(this.code, this.language);
}

/// Event to update selected currency.
class UpdateCurrencyEvent extends AccountEvent {
  final String currency;

  const UpdateCurrencyEvent(this.currency);
}

/// Event to update selected timezone.
class UpdateTimezoneEvent extends AccountEvent {
  final String timezone;

  const UpdateTimezoneEvent(this.timezone);
}

/// Event to load cache size information.
class LoadCacheSize extends AccountEvent {}

/// Event to clear application cache.
class ClearCacheEvent extends AccountEvent {}

/// Event to enable biometric authentication.
class EnableBiometric extends AccountEvent {}

/// Event to disable biometric authentication.
class DisableBiometric extends AccountEvent {}

/// Event to initialize biometric state from stored value.
class SetBiometricInitial extends AccountEvent {
  final bool enabled;

  const SetBiometricInitial(this.enabled);
}

/// Event to pick an image from camera or gallery.
class PickImageEvent extends AccountEvent {
  final ImageSource source;

  const PickImageEvent(this.source);

  @override
  List<Object?> get props => [source];
}

/// Event to update selected country.
class UpdateCountryEvent extends AccountEvent {
  final Map<String, dynamic>? country;

  const UpdateCountryEvent(this.country);
}

/// Event to update selected state.
class UpdateStateEvent extends AccountEvent {
  final Map<String, dynamic>? state;

  const UpdateStateEvent(this.state);
}

/// Event to update user profile information.
///
/// Can be used for both general profile update and address update
/// depending on [isAddress].
class UpdateProfile extends AccountEvent {
  final bool? isAddress;
  final int? partnerId;

  final String? name;
  final String? mail;
  final String? phone;
  final String? mobile;
  final String? website;
  final String? function;
  final String? image;

  final String? street1;
  final String? street2;
  final String? city;
  final String? zip;
  final int? stateId;
  final int? countryId;

  const UpdateProfile({
    this.isAddress,
    this.partnerId,

    this.name,
    this.mail,
    this.phone,
    this.mobile,
    this.website,
    this.function,
    this.image,

    this.street1,
    this.street2,
    this.city,
    this.zip,
    this.stateId,
    this.countryId,
  });

  @override
  List<Object?> get props => [
    isAddress,
    partnerId,

    name,
    mail,
    phone,
    mobile,
    website,
    function,
    image,

    street1,
    street2,
    city,
    zip,
    stateId,
    countryId,
  ];
}

/// Event to clear temporary UI messages in AccountBloc.
class ClearAccountMessage extends AccountEvent {}

/// Drops a photo picked in edit mode (Cancel), so the page shows the saved one.
class ClearPickedImage extends AccountEvent {
  const ClearPickedImage();
}

/// Sets the partner's related company; null clears it.
class UpdateRelatedCompany extends AccountEvent {
  final int? partnerId;
  final int? companyId;

  const UpdateRelatedCompany({this.partnerId, this.companyId});

  @override
  List<Object?> get props => [partnerId, companyId];
}
