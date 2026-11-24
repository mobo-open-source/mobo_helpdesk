/// Returns the human-readable group title corresponding to a given technical group value.
///
/// This function looks up the provided [value] inside
/// [groupSlaPolicyTechnicalNames] and returns the matching map key
/// (the display name used in UI grouping).
///
/// If the [value] is null or no matching entry is found,
/// it returns `null`.
///
/// Example:
/// ```dart
/// getGroupTitleFromValue("helpdesk_team"); // "Helpdesk Team"
/// getGroupTitleFromValue(null); // null
/// ```
String? getGroupTitleFromValue(String? value) {
  if (value == null) return null;

  try {
    return groupSlaPolicyTechnicalNames.entries
        .firstWhere((entry) => entry.value['value'] == value)
        .key;
  } catch (e) {
    return null;
  }
}

/// Defines available SLA policy grouping options used in the UI filter.
///
/// Each entry contains:
/// - `value`: backend/technical identifier used for grouping
/// - `description`: human-readable explanation shown in UI
///
/// Example:
/// - "None" → no grouping applied
/// - "Helpdesk Team" → grouped by helpdesk team
final Map<String, Map<String, dynamic>> groupSlaPolicyTechnicalNames = {
  "None": {"value": null, "description": "No grouping applied"},
  "Helpdesk Team": {
    "value": "helpdesk_team",
    "description": "SLA policies grouped by helpdesk team",
  },
};
