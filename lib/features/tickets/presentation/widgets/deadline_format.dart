/// Formats a deadline date string into a human-readable relative time.
///
/// This function converts a date string into a relative description based on
/// the difference from today's date.
///
/// Examples:
/// - "2026-04-14" → "Today"
/// - "2026-04-15" → "Tomorrow"
/// - "2026-04-13" → "1 day ago"
/// - Future dates → "In X days"
/// - Past dates → "X days ago"
///
/// If the input is empty or invalid, it returns the original string.
///
/// [dateStr] The input date string in ISO 8601 format or parseable format.
///
/// Returns a formatted relative date string.
String formatDeadline(String dateStr) {
  if (dateStr.isEmpty) return '';

  final deadline = DateTime.tryParse(dateStr);
  if (deadline == null) return dateStr;

  final now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(deadline.year, deadline.month, deadline.day);

  final difference = target.difference(today).inDays;

  if (difference == 0) return "Today";
  if (difference == -1) return "1 day ago";
  if (difference == 1) return "Tomorrow";

  if (difference < 0) {
    return "${difference.abs()} days ago";
  } else {
    return "In $difference days";
  }
}
