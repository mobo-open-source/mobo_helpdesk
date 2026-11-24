import '../../../core/utils/odoo_values.dart';

/// Turns what the team form holds into the values Odoo's `helpdesk.team` takes.
///
/// The same steps apply to a create and an update; an update additionally sends
/// only what changed, so saving a team never rewrites the fields the user did
/// not touch (and never trips a constraint on stored data it did not edit).
class TeamValues {
  const TeamValues._();

  /// Many2many fields the form sends as a list of ids.
  static const _manyKeys = {
    'member_ids',
    'from_stage_ids',
    'message_partner_ids',
  };

  /// Many2one fields: left out while empty on a create, and cleared with
  /// `false` on an update when the user emptied one that had a value.
  static const _relationKeys = {
    'alias_domain_id',
    'website_id',
    'project_id',
    'resource_calendar_id',
    'to_stage_id',
    'reminder_email_template_id',
  };

  /// HTML fields, compared by their text.
  static const _htmlKeys = {'description'};

  /// The values to send for [data].
  ///
  /// - Only fields this server has, and none that are empty (`null`).
  /// - The auto-close period is a whole number of days, at least 1, and the
  ///   reminder delay at least 0. The form holds them as text, and an empty
  ///   one is not 0: it means "not set", so Odoo's own default (7 and 2 days)
  ///   applies. Odoo 20 rejects a team whose reminder delay is not shorter than
  ///   its auto-close period, which is what sending `''` (read as 0) did.
  /// - Many2many fields as replace-all commands.
  ///
  /// With [current] - the team as read from the server - only values that
  /// differ from it are returned: an empty map means there is nothing to save.
  static Map<String, dynamic> prepare(
    Map<String, dynamic> data, {
    required Set<String> validFields,
    Map<String, dynamic>? current,
  }) {
    final values = <String, dynamic>{};

    data.forEach((key, value) {
      if (!validFields.contains(key)) return;
      if (value == null) {
        // Emptying a relation on an existing team is a real edit.
        if (current != null &&
            _relationKeys.contains(key) &&
            OdooValues.relationId(current[key]) != null) {
          values[key] = false;
        }
        return;
      }
      values[key] = value;
    });

    _wholeDays(values, 'auto_close_day', atLeast: 1);
    _wholeDays(values, 'auto_close_reminder_delay', atLeast: 0);

    for (final key in _manyKeys) {
      final value = values[key];
      if (value is List) values[key] = OdooValues.replaceWith(value);
    }

    if (current != null) {
      values.removeWhere(
        (key, value) => OdooValues.unchanged(
          value,
          current[key],
          html: _htmlKeys.contains(key),
        ),
      );
    }
    return values;
  }

  /// Makes [key] a whole number, or removes it when it is not one of at least
  /// [atLeast].
  static void _wholeDays(
    Map<String, dynamic> values,
    String key, {
    required int atLeast,
  }) {
    if (!values.containsKey(key)) return;
    final raw = values[key];
    final days = raw is num ? raw.toInt() : int.tryParse('$raw'.trim());
    if (days == null || days < atLeast) {
      values.remove(key);
    } else {
      values[key] = days;
    }
  }
}
