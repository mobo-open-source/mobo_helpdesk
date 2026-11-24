import '../../../../core/utils/odoo_binary.dart';
import '../../domain/entities/main_layout_entity.dart';

/// Data model representing the user profile information for the main layout.
///
/// This model extends [MainLayoutEntity] and is responsible for converting
/// raw JSON data (typically from an API or backend like Odoo) into a structured
/// Dart object used within the application.
///
/// It handles safe parsing of fields such as:
/// - `id` (user identifier)
/// - `name` (user display name)
/// - `email` (user email address)
/// - `image_1920` (base64 or URL encoded profile image)
///
/// If any field is missing or has an unexpected type, default fallback values
/// are used to prevent runtime errors.
class MainLayoutModel extends MainLayoutEntity {
  MainLayoutModel({
    required super.id,
    required super.name,
    required super.mail,
    required super.image,
  });

  factory MainLayoutModel.fromJson(Map<String, dynamic> json) {
    return MainLayoutModel(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : '',
      mail: json['email'] is String ? json['email'] : '',
      image: odooBinaryToBase64(json['image_1920']),
    );
  }
}
