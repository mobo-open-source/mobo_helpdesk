/// Safely converts a dynamic value to a displayable string.
///
/// Returns "—" (em dash) for null or false values — useful for UI tables
/// and detail views to show "no data" in a clean way.
String safeViewText(dynamic value) {
  if (value == null || value == false) return "—";
  return value.toString();
}

/// Safely extracts a non-empty string value.
///
/// Returns an empty string if the value is not a non-empty String.
/// Useful when updating text fields or forms to avoid null errors.
String safeUpdateText(dynamic value) {
  return (value is String && value.isNotEmpty) ? value : '';
}

/// Safely executes an API call that returns a List and catches any exceptions.
///
/// Returns an empty list `[]` if the API call fails for any reason.
/// Prevents the entire UI from crashing due to network or parsing errors.
Future<List> safeApiCall(Future<List> Function() apiCall) async {
  try {
    return await apiCall();
  } catch (e) {
    return [];
  }
}

/// Safely formats a value for grouping (used in charts, filters, or grouped lists).
///
/// - `null` or empty values → `"None"`
/// - Empty String → `"None"`
/// - Empty List or Map → `"None"`
/// - Otherwise returns the string representation of the value.
String safeGroupValue(dynamic value) {
  if (value == null) return "None";

  if (value is String) {
    if (value.trim().isEmpty) return "None";
    return value;
  }

  if (value is List || value is Map) {
    if (value.isEmpty) return "None";
    return value.toString();
  }

  return value.toString();
}

/// Converts a dynamic list into a typed `List<Map<String, dynamic>>`.
///
/// Filters out any items that are not proper maps. Useful when processing
/// Odoo `search_read` results.
List<Map<String, dynamic>> toMapList(List<dynamic> list) {
  return list.whereType<Map<String, dynamic>>().toList();
}

/// Safely converts a dynamic value to an integer.
///
/// Returns `0` if conversion fails.
int toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

/// Safely converts a dynamic value to a double and rounds it to 1 decimal place.
///
/// Returns `0.0` if conversion fails.
double toDouble(dynamic value) {
  if (value == null) return 0.0;

  double result;

  if (value is double) {
    result = value;
  } else if (value is int) {
    result = value.toDouble();
  } else {
    result = double.tryParse(value.toString()) ?? 0.0;
  }

  return double.parse(result.toStringAsFixed(1));
}

String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}
