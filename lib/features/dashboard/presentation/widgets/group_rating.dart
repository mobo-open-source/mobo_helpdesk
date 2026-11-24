import 'package:mobo_helpdesk/features/dashboard/domain/entities/rating_entity.dart';

import '../../../../core/utils/group_date_format_utils.dart';
import '../../../../core/utils/safe_utils.dart';
import '../bloc/dashboard_bloc.dart';

/// Groups a list of [RatingEntity] objects based on the specified `groupBy` criteria.
///
/// This utility function is used in [RatingListPage] when the user selects a grouping
/// option (e.g., by Team, Customer, Resource, Date, etc.). It transforms a flat list
/// of ratings into a grouped structure suitable for expandable list UI.
///
/// Parameters:
///   - [ratings]: The list of rating entities to be grouped.
///   - [groupBy]: The grouping key. Supported values are:
///     - `'assigned'`     → Group by related partner (Assigned To)
///     - `'helpdesk_team'`→ Group by partner resource name (Team)
///     - `'customer'`     → Group by customer/partner name
///     - `'resource'`     → Group by ticket resource name
///     - `'date'`         → Group by formatted date using [state.selectedDateUnit]
///   - [state]: The current [DashboardState] containing `selectedDateUnit`
///              (required when `groupBy` is `'date'`).
///
/// Returns:
///   A list of maps, where each map represents a group and contains:
///   - `"group"`: The name of the group (String)
///   - `"ratings"`: List of [RatingEntity] belonging to that group
///
/// Example:
/// ```dart
/// final grouped = groupRating(ratings, 'customer', dashboardState);
/// // Result: [
/// //   {"group": "Acme Corp", "ratings": [...]},
/// //   {"group": "Beta Inc", "ratings": [...]},
/// // ]
/// ```
List<Map<String, dynamic>> groupRating(
  List<RatingEntity> ratings,
  String groupBy,
  DashboardState state,
) {
  final Map<String, List<RatingEntity>> grouped = {};

  for (var rating in ratings) {
    String key = "None";

    switch (groupBy) {
      case 'assigned':
        key = safeGroupValue(rating.relatedPartnerId['name']);
        break;

      case 'helpdesk_team':
        key = safeGroupValue(rating.partnerResName);
        break;

      case 'customer':
        key = safeGroupValue(rating.partnerId['name']);
        break;

      case 'resource':
        key = safeGroupValue(rating.resName);
        break;

      case 'date':
        key = safeGroupValue(
          formatDateGroup(rating.createDate, state.selectedDateUnit ?? 'day'),
        );
        break;

      default:
        key = "None";
    }

    grouped.putIfAbsent(key, () => []).add(rating);
  }

  return grouped.entries.map((e) {
    return {"group": e.key, "ratings": e.value};
  }).toList();
}
