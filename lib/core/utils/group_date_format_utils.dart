/// Formats a date string into a group label based on the specified [dateUnit].
///
/// This function is commonly used for grouping records (e.g., tickets, tasks, or reports)
/// by time periods such as Year, Quarter, Month, Week, or Day.
///
/// Supported units:
/// - `'year'`    → `"2025"`
/// - `'quarter'` → `"Q1 2025"`, `"Q2 2025"`, etc.
/// - `'month'`   → `"2025-04"`
/// - `'week'`    → First day of the week in `YYYY-MM-DD` format (Monday-based)
/// - `'day'`     → `"2025-04-14"` (default)
///
/// Returns:
/// - `"No Date"` if the input is empty.
/// - `"Invalid Date"` if the date cannot be parsed.
///
/// Example:
/// ```dart
/// formatDateGroup("2025-04-14", "quarter")  // → "Q2 2025"
/// formatDateGroup("2025-04-14", "month")    // → "2025-04"
/// formatDateGroup("2025-04-14", "week")     // → "2025-04-14" (Monday of that week)
/// ```
String formatDateGroup(String date, String dateUnit) {
  if (date.isEmpty) return "No Date";

  final parsed = DateTime.tryParse(date);
  if (parsed == null) return "Invalid Date";

  switch (dateUnit) {
    case 'year':
      return parsed.year.toString();

    case 'quarter':
      final q = ((parsed.month - 1) ~/ 3) + 1;
      return "Q$q ${parsed.year}";

    case 'month':
      return "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}";

    case 'week':
      final firstDay = parsed.subtract(Duration(days: parsed.weekday));
      return "${firstDay.year}-${firstDay.month}-${firstDay.day}";

    case 'day':
    default:
      return "${parsed.year}-${parsed.month}-${parsed.day}";
  }
}