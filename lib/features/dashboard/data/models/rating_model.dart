import '../../domain/entities/rating_entity.dart';

/// Data model for a rating record coming from the API.
///
/// This class extends [RatingEntity] and is responsible for:
/// - Mapping raw JSON from the backend (Odoo API)
/// - Converting relational fields (many2one) into structured maps
/// - Handling null/false safety for string values
class RatingModel extends RatingEntity {
  RatingModel({
    required super.id,
    required super.relatedPartnerId,
    required super.partnerId,
    required super.partnerResName,
    required super.resName,
    required super.resId,
    required super.ratingText,
    required super.createDate,
  });

  static Map<String, dynamic> parseRelation(dynamic field) {
    if (field is List && field.length >= 2) {
      return {'id': field[0], 'name': field[1]};
    }
    return {'id': 0, 'name': ''};
  }

  static String parseString(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: 0,
      relatedPartnerId: parseRelation(json['rated_partner_id']),
      partnerId: parseRelation(json['partner_id']),
      partnerResName: parseString(json['parent_res_name']),
      resName: parseString(json['res_name']),
      resId: json['res_id'],
      ratingText: parseString(json['rating_text']),
      createDate: parseString(json['create_date']),
    );
  }
}
