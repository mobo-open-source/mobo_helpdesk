/// Returns the display title (key) for a given group value.
///
/// This function searches inside [groupTicketTechnicalNames] and returns
/// the first matching key whose `"value"` matches the provided [value].
///
/// Example:
/// - Input: `"assigned"` → Output: `"Assigned to"`
/// - Input: `"stage"` → Output: `"Stage"`
///
/// If no match is found or [value] is null, returns null.
String? getGroupTitleFromValue(String? value) {
  if (value == null) return null;

  try {
    return groupTicketTechnicalNames.entries
        .firstWhere((entry) => entry.value['value'] == value)
        .key;
  } catch (e) {
    return null;
  }
}

/// Mapping of ticket grouping options.
///
/// Key → Display label shown in UI
/// Value → Metadata containing:
/// - value: backend technical identifier
/// - description: explanation of grouping behavior
/// - hasUnits: optional flag for date-based grouping
final Map<String, Map<String, dynamic>> groupTicketTechnicalNames = {
  "None": {"value": null, "description": "No grouping applied"},

  "Assigned to": {
    "value": "assigned",
    "description": "Tickets grouped by assigned user",
  },
  "Helpdesk Team": {
    "value": "helpdesk_team",
    "description": "Tickets grouped by helpdesk team",
  },
  "Stage": {"value": "stage", "description": "Tickets grouped by stage"},
  "SLA": {"value": "sla", "description": "Grouped based on SLA status"},
  "Type": {"value": "type", "description": "Grouped by ticket type"},
  "Tags": {"value": "tags", "description": "Grouped by tags"},
  "Priority": {"value": "priority", "description": "Grouped by priority level"},
  "Partner": {"value": "partner", "description": "Grouped by customer/partner"},
  "Creation Date": {
    "value": "create_date",
    "description": "Grouped by ticket creation date",
    "hasUnits": true,
  },
  "SLA Deadline": {
    "value": "sla_deadline",
    "description": "Grouped by SLA deadline",
    "hasUnits": true,
  },
};
