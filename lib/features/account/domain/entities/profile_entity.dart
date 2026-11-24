/// Core domain entity representing a user profile.
///
/// This entity is used across the domain layer and contains
/// user-related information such as personal details,
/// contact information, and company association.
///
/// It is independent of any data source (API, database, etc.)
class ProfileEntity {
  final int id;
  final String name;
  final int partnerId;
  final String phone;
  final String mail;
  final String contactAddress;
  final dynamic companyId;
  final String street;
  final String street2;
  final dynamic stateId;
  final dynamic countryId;
  final String image;
  final String website;
  final String function;
  final String mobile;
  final dynamic parentId;
  final String city;
  final String zip;

  /// Whether this server has anywhere to store the number; the screen hides
  /// the row otherwise instead of offering an edit that would be dropped.
  final bool hasMobileField;
  final bool hasPhoneField;

  ProfileEntity({
    required this.id,
    required this.name,
    required this.partnerId,
    required this.phone,
    required this.mail,
    required this.contactAddress,
    required this.companyId,
    required this.street,
    required this.street2,
    required this.stateId,
    required this.countryId,
    required this.image,
    required this.website,
    required this.function,
    required this.mobile,
    this.parentId,
    this.city = '',
    this.zip = '',
    this.hasMobileField = true,
    this.hasPhoneField = true,
  });
}
