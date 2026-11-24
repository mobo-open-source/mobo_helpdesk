/// The base64 text of a binary field read from Odoo, or `''` when it is empty.
///
/// Up to Odoo 19 a binary field such as `image_1920` reads as a base64 string,
/// or `false` when nothing is stored. Odoo 20 reads it as
/// `{content: <base64>, size: <bytes>, filename: <name>}` (the filename only
/// when there is one), still `false` when empty. Both are accepted here so the
/// photo shows whichever server the account belongs to.
///
/// Writing is unchanged: Odoo 20 still takes a plain base64 string.
String odooBinaryToBase64(dynamic value) {
  if (value is String) return value;
  if (value is Map && value['content'] is String) {
    return value['content'] as String;
  }
  return '';
}
