import '../widgets/ignore_tag.dart' show stripHtmlTags;

/// Shapes of the values Odoo's `create` and `write` take, and of the ones
/// `read` gives back.
///
/// Odoo reads a many2one as `[id, name]` and a many2many as a list of ids, but
/// takes a many2many as a list of *commands*. A plain list of ids is not a
/// replacement: it can add or swap members, yet an empty list changes nothing,
/// so a form could never clear one. [replaceWith] is the form that always means
/// "exactly these".
class OdooValues {
  const OdooValues._();

  /// The write value that makes a many2many or one2many hold exactly [ids].
  static List<dynamic> replaceWith(Iterable<dynamic> ids) => [
    [6, 0, ids.whereType<int>().toList()],
  ];

  /// The id of a many2one however it arrives: `[id, name]`, `{id, ...}` or a
  /// bare id. `null` when empty (Odoo reads an empty one as `false`).
  static int? relationId(dynamic value) {
    if (value is int) return value;
    if (value is List && value.isNotEmpty && value.first is int) {
      return value.first as int;
    }
    if (value is Map && value['id'] is int) return value['id'] as int;
    return null;
  }

  /// The ids a many2many holds, from a read (a list of ids) or from the
  /// replace-all command [replaceWith] makes.
  static Set<int> relationIds(dynamic value) {
    if (value is! List) return <int>{};
    final ids = <int>{};
    for (final item in value) {
      if (item is int) {
        ids.add(item);
      } else if (item is List && item.length == 3 && item[0] == 6) {
        ids.addAll(relationIds(item[2]));
      }
    }
    return ids;
  }

  /// Whether [sent] says what Odoo already holds in [stored], so writing it
  /// would change nothing.
  ///
  /// Text compares as plain text when [html] is set: an HTML field read as
  /// `<p>Hi</p>` and shown as `Hi` has not changed when `Hi` comes back.
  static bool unchanged(dynamic sent, dynamic stored, {bool html = false}) {
    // A command list against the ids a read gives back.
    if (sent is List) {
      final sentIds = relationIds(sent);
      final storedIds = relationIds(stored);
      return sentIds.length == storedIds.length &&
          sentIds.containsAll(storedIds);
    }

    // Many2one: an id against `[id, name]`, `false` meaning empty.
    if (sent is int && (stored is List || stored == false)) {
      return relationId(stored) == sent;
    }

    if (sent is String) {
      final storedText = stored is String ? stored : '';
      return html
          ? stripHtmlTags(storedText).trim() == sent.trim()
          : storedText == sent;
    }

    if (sent is bool) {
      if (stored is bool) return stored == sent;
      // `false` also clears a relation or a text (Odoo reads an empty one as
      // `false`): it only says "no change" when nothing was set.
      if (stored == null) return !sent;
      if (stored is List || stored is String) {
        return !sent && (stored as dynamic).isEmpty == true;
      }
      return false;
    }

    if (sent is num && stored is num) return sent == stored;

    return sent == stored;
  }
}
