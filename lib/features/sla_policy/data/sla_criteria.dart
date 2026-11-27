import '../../../core/utils/odoo_domain.dart';
import '../../../core/utils/odoo_field_resolver.dart';

/// Bridges the criteria the SLA screens edit and how the server keeps them.
///
/// Up to Odoo 19 a `helpdesk.sla` records which tickets it applies to in
/// separate fields: `priority` (a minimum), `tag_ids` and `partner_ids`. Odoo 20
/// replaced them with one domain in `criteria_domain`, which can say much more
/// than the screens can show. The screens keep working in the old terms and this
/// class converts at the boundary, in both directions:
///
/// - [expand] rewrites a record read from the server into the old fields;
/// - [toServer] rewrites values the screens saved into `criteria_domain`.
///
/// Clauses the screens do not own - anything an Odoo user added in the web
/// client - are carried through a save unchanged rather than dropped.
class SlaCriteria {
  const SlaCriteria._();

  static const _model = 'helpdesk.sla';

  /// The Odoo 20 field that holds the criteria.
  static const domainField = 'criteria_domain';

  /// The fields the screens edit; Odoo 20 has none of them.
  static const _screenFields = ['priority', 'tag_ids', 'partner_ids'];

  /// Whether this server keeps the criteria in [domainField].
  ///
  /// `criteria_domain` is new in Odoo 20, so when the server cannot be asked it
  /// is taken to be absent: the older fields are what every other version has.
  static Future<bool> storedAsDomain() =>
      OdooFieldResolver.hasField(_model, domainField, assumeIfUnknown: false);

  /// Adds `priority`, `tag_ids` and `partner_ids` to [record], worked out from
  /// its [domainField].
  static void expand(Map<String, dynamic> record) {
    final criteria = _Criteria.parse(record[domainField]);
    record['priority'] = criteria.priority?.toString() ?? '0';
    record['tag_ids'] = criteria.tagIds ?? <int>[];
    record['partner_ids'] = criteria.partnerIds ?? <int>[];
  }

  /// Rewrites [data], as saved by the screens, into the values Odoo 20 takes.
  ///
  /// [data] is returned as it is when it carries no criteria, so a write that
  /// only renames a policy leaves its criteria alone. [currentDomain] is the
  /// policy's stored [domainField], needed to keep the clauses the screens do
  /// not own when updating.
  ///
  /// Throws [SlaCriteriaException] when [currentDomain] is something this app
  /// cannot read and [data] asks for new criteria on top of it: replacing it
  /// would silently drop whatever it says.
  static Map<String, dynamic> toServer(
    Map<String, dynamic> data, {
    String? currentDomain,
  }) {
    if (!_screenFields.any(data.containsKey)) return data;

    final values = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) => _screenFields.contains(key))
      ..remove('ticket_type_ids');

    final priority = int.tryParse('${data['priority'] ?? 0}') ?? 0;
    final tagIds = _ids(data['tag_ids']);
    final partnerIds = _ids(data['partner_ids']);
    final asksForCriteria =
        priority > 0 || tagIds.isNotEmpty || partnerIds.isNotEmpty;

    final criteria = _Criteria.parse(currentDomain);
    if (criteria.unreadable) {
      if (!asksForCriteria) return values; // nothing to change; keep it as is
      throw const SlaCriteriaException(
        'This policy has criteria that can only be edited in Odoo.',
      );
    }

    final domain = <dynamic>[
      ...criteria.others,
      if (priority > 0) ['priority', '>=', '$priority'],
      if (tagIds.isNotEmpty) ['tag_ids', 'in', tagIds],
      if (partnerIds.isNotEmpty) ['partner_id', 'in', partnerIds],
    ];

    // An empty domain is stored as no text at all, as Odoo itself does.
    values[domainField] = domain.isEmpty ? false : OdooDomain.format(domain);
    return values;
  }

  static List<int> _ids(dynamic value) =>
      value is List ? value.whereType<int>().toList() : <int>[];
}

/// The criteria cannot be saved without losing part of what is stored.
class SlaCriteriaException implements Exception {
  const SlaCriteriaException(this.message);

  /// Wording that can be shown to the user as it is.
  final String message;

  @override
  String toString() => message;
}

/// A stored criteria domain, sorted into what the screens edit and the rest.
class _Criteria {
  _Criteria._({
    this.priority,
    this.tagIds,
    this.partnerIds,
    this.others = const [],
    this.unreadable = false,
  });

  /// The minimum priority, when the domain has the clause the screens write.
  final int? priority;
  final List<int>? tagIds;
  final List<int>? partnerIds;

  /// Every other top-level expression, flattened back into one domain.
  final List<dynamic> others;

  /// The text is not a domain this app can read.
  final bool unreadable;

  factory _Criteria.parse(dynamic stored) {
    final text = stored is String ? stored : null;
    final domain = OdooDomain.tryParse(text);
    final expressions = domain == null
        ? null
        : OdooDomain.splitTopLevel(domain);
    if (expressions == null) return _Criteria._(unreadable: true);

    int? priority;
    List<int>? tagIds;
    List<int>? partnerIds;
    final others = <dynamic>[];

    for (final expression in expressions) {
      final leaf = expression.length == 1 && expression.first is List
          ? expression.first as List
          : null;
      if (leaf != null && leaf.length == 3) {
        final field = leaf[0];
        final operator = leaf[1];
        final value = leaf[2];

        if (priority == null &&
            field == 'priority' &&
            operator == '>=' &&
            int.tryParse('$value') != null) {
          priority = int.parse('$value');
          continue;
        }
        if (tagIds == null &&
            field == 'tag_ids' &&
            operator == 'in' &&
            value is List) {
          tagIds = value.whereType<int>().toList();
          continue;
        }
        if (partnerIds == null &&
            field == 'partner_id' &&
            operator == 'in' &&
            value is List) {
          partnerIds = value.whereType<int>().toList();
          continue;
        }
      }
      others.addAll(expression);
    }

    return _Criteria._(
      priority: priority,
      tagIds: tagIds,
      partnerIds: partnerIds,
      others: others,
    );
  }
}
