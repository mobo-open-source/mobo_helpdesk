/// A mapping of user-friendly group labels to their technical configuration
/// used for grouping ratings in [RatingListPage].
///
/// This map is passed to [FilterGroupWidget] to populate the "Group By" section
/// in the filter bottom sheet. It defines available grouping options along with
/// their internal values and metadata.
///
/// Structure of each entry:
/// - **Key**: Display name shown to the user in the filter UI.
/// - **Value**: A map containing:
///   - `"value"`: The technical key sent to the backend / used in [groupRating()].
///   - `"description"`: Human-readable explanation of the grouping.
///   - `"hasUnits"` (optional): `true` if this group supports date units
///     (Year, Quarter, Month, Week, Day) — currently only applies to "Date".
///
/// Used in conjunction with [groupRating()] function.
final Map<String, Map<String, dynamic>> groupRatingTechnicalNames = {
  "None": {"value": null, "description": "No grouping applied"},

  "Assigned to": {
    "value": "assigned",
    "description": "Ratings grouped by assigned user",
  },
  "Customer": {
    "value": "customer",
    "description": "Ratings grouped by Customer",
  },
  "Helpdesk Team": {
    "value": "helpdesk_team",
    "description": "Ratings grouped by helpdesk team",
  },
  "Resource": {
    "value": "resource",
    "description": "Ratings grouped by resource",
  },
  "Date": {
    "value": "date",
    "description": "Grouped by rating submission date",
    "hasUnits": true,
  },
};
