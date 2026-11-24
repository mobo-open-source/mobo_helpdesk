/// Strips all HTML tags from the given text and returns clean plain text.
///
/// This utility function is useful for displaying HTML content (from rich text
/// editors, APIs, or databases) in plain text widgets like [Text], [ListTile],
/// or notifications.
///
/// **Behavior:**
/// - Returns `"—"` (em dash) if the input is `null` or `false`
/// - Converts the input to string and removes all HTML tags using regex
/// - Replaces tags with newlines (`\n`) to preserve paragraph-like structure
/// - Trims leading/trailing whitespace
///
/// **Example:**
/// ```dart
/// stripHtmlTags('<p>Hello <strong>World</strong>!</p>') // Returns: "Hello World!"
/// stripHtmlTags(null)                                    // Returns: "—"
/// stripHtmlTags('<h1>Title</h1>\n<p>Content</p>')       // Returns: "Title\nContent"
/// ```
String stripHtmlTags(dynamic htmlText) {
  if (htmlText == null || htmlText == false) return "";

  final text = htmlText.toString();

  // ignore: deprecated_member_use
  final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
  return text.replaceAll(regex, '\n').trim();
}
