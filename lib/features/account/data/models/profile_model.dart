import '../../../../core/utils/odoo_binary.dart';
import '../../domain/entities/profile_entity.dart';

/// Data model for user profile information.
///
/// Extends [ProfileEntity] and is responsible for
/// mapping JSON responses from the backend into a
/// strongly-typed domain entity.
///
/// Used for:
/// - Parsing user profile API response
/// - Converting backend fields into domain-friendly structure
class ProfileModel extends ProfileEntity {
  ProfileModel({
    required super.id,
    required super.name,
    required super.partnerId,
    required super.phone,
    required super.mail,
    required super.contactAddress,
    required super.companyId,
    required super.street,
    required super.street2,
    required super.stateId,
    required super.countryId,
    required super.image,
    required super.website,
    required super.function,
    required super.mobile,
    super.parentId,
    super.city,
    super.zip,
    super.hasMobileField,
    super.hasPhoneField,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : '',
      partnerId: json['partner_id'][0],
      phone: json['phone'] is String ? json['phone'] : '',
      mail: json['email'] is String ? json['email'] : '',
      contactAddress: json['contact_address'] is String
          ? json['contact_address']
          : '',
      companyId: json['company_id'],
      street: json['street'] is String ? json['street'] : '',
      street2: json['street2'] is String ? json['street2'] : '',
      stateId: json['state_id'],
      countryId: json['country_id'],
      image: odooBinaryToBase64(json['image_1920']),
      website: json['website'] is String ? json['website'] : '',
      function: json['function'] is String ? json['function'] : '',
      mobile: json['mobile'] is String ? json['mobile'] : '',
      parentId: json['parent_id'],
      city: json['city'] is String ? json['city'] : '',
      zip: json['zip'] is String ? json['zip'] : '',
      hasMobileField: json['has_mobile_field'] != false,
      hasPhoneField: json['has_phone_field'] != false,
    );
  }
}
