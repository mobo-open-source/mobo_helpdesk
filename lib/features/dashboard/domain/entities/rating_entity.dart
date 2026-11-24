/// Core domain entity representing a rating record in the system.
///
/// This entity is independent of API/data source implementation and
/// is used throughout the domain and presentation layers.
///
/// It represents feedback/rating data linked to a resource (e.g., helpdesk ticket)
/// and includes partner information, rating type, and creation timestamp.
class RatingEntity {
  final int id;
  final Map<String, dynamic> relatedPartnerId;
  final Map<String, dynamic> partnerId;
  final String partnerResName;
  final String resName;
  final int resId;
  final String ratingText;
  final String createDate;

  RatingEntity({
    required this.id,
    required this.relatedPartnerId,
    required this.partnerId,
    required this.partnerResName,
    required this.resName,
    required this.resId,
    required this.ratingText,
    required this.createDate,
  });
}
