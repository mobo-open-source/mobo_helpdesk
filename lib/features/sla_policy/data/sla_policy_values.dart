import '../../../core/utils/odoo_values.dart';
import 'sla_criteria.dart';

/// Turns what the SLA policy form holds into the values Odoo's `helpdesk.sla`
/// takes, for a create and for an update.
///
/// An update additionally sends only what changed, so saving a policy never
/// rewrites what the user did not touch.
class SlaPolicyValues {
  const SlaPolicyValues._();

  /// Many2many fields the form sends as a list of ids.
  static const manyKeys = {
    'tag_ids',
    'partner_ids',
    'ticket_type_ids',
    'exclude_stage_ids',
  };

  /// The fields this class may need to read back from the server to tell what
  /// changed, whatever the version: the criteria in either of their forms.
  static const criteriaKeys = [
    'priority',
    'tag_ids',
    'partner_ids',
    'ticket_type_ids',
    SlaCriteria.domainField,
  ];

  /// The values to send for [data].
  ///
  /// - [criteriaAsDomain] (Odoo 20): priority, tags and customers become one
  ///   `criteria_domain`, keeping the clauses of [currentDomain] the form does
  ///   not own; see [SlaCriteria].
  /// - Many2many fields as replace-all commands, which, unlike a plain list,
  ///   can also empty them.
  /// - `time` (the hours the policy allows) as a number: the form holds text,
  ///   and an empty or unreadable one is left out so Odoo's own default stays.
  /// - Only fields this server has ([validFields]).
  ///
  /// With [current] - the policy as read from the server - only values that
  /// differ from it are returned: an empty map means there is nothing to save.
  ///
  /// Throws [SlaCriteriaException] when the criteria cannot be changed without
  /// losing part of what is stored.
  static Map<String, dynamic> prepare(
    Map<String, dynamic> data, {
    required bool criteriaAsDomain,
    required Set<String> validFields,
    Map<String, dynamic>? current,
  }) {
    var values = criteriaAsDomain
        ? SlaCriteria.toServer(
            data,
            currentDomain: current?[SlaCriteria.domainField] is String
                ? current![SlaCriteria.domainField] as String
                : null,
          )
        : Map<String, dynamic>.from(data);

    values = {
      for (final entry in values.entries)
        if (entry.value != null && validFields.contains(entry.key))
          entry.key: entry.value,
    };

    if (values.containsKey('time')) {
      final raw = values['time'];
      final hours = raw is num
          ? raw.toDouble()
          : double.tryParse('$raw'.trim().replaceAll(',', '.'));
      if (hours == null || hours < 0) {
        values.remove('time');
      } else {
        values['time'] = hours;
      }
    }

    for (final key in manyKeys) {
      final value = values[key];
      if (value is List) values[key] = OdooValues.replaceWith(value);
    }

    if (current != null) {
      values.removeWhere(
        (key, value) => OdooValues.unchanged(
          value,
          current[key],
          html: key == 'description',
        ),
      );
    }
    return values;
  }
}
