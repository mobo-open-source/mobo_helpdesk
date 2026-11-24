import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/odoo_record_counts.dart';
import '../../../../core/widgets/api_validation_error.dart';
import '../sla_criteria.dart';
import '../sla_policy_values.dart';

/// Abstract datasource for SLA Policy form operations.
///
/// Defines all remote API operations required to:
/// - Load SLA policy details
/// - Fetch related Helpdesk data (teams, types, tags, customers)
/// - Manage stage filtering logic
/// - Create and update SLA policies
///
/// This layer acts as a contract between the data layer and domain layer.
abstract class SlaPolicyFormRemoteDatasource {
  Future<List<Map<String, dynamic>>> loadPolicyData(int id);

  Future<List<Map<String, dynamic>>> loadHelpdeskTeam();

  Future<List<Map<String, dynamic>>> loadTypes();

  Future<List<Map<String, dynamic>>> loadTags();

  Future<List<Map<String, dynamic>>> loadCustomers();

  Future<List<Map<String, dynamic>>> loadReachStages(
    int teamId,
    List excludeStageIds,
  );

  Future<List<Map<String, dynamic>>> loadExcludingStages(
    int teamId,
    int stageId,
  );

  Future<void> createPolicy(Map<String, dynamic> data);

  Future<void> updatePolicy(int id, Map<String, dynamic> data);
}

/// Implementation of [SlaPolicyFormRemoteDatasource] using Odoo RPC.
///
/// Handles API communication with Odoo backend via [CompanySessionManager]
/// and maps raw responses into structured data for SLA policy management.
class SlaPolicyFormRemoteDatasourceImpl
    implements SlaPolicyFormRemoteDatasource {
  /// Fetches display names for related record IDs.
  ///
  /// Used for resolving relational fields like tags, partners, etc.
  Future<List<Map<String, dynamic>>> fetchNames(String model, List ids) async {
    if (ids.isEmpty) return [];

    final fields = model == 'helpdesk.tag'
        ? ['id', 'name', 'color']
        : ['id', 'name'];

    final response = await CompanySessionManager.callKwWithCompany({
      'model': model,
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', ids],
        ],
      ],
      'kwargs': {'fields': fields},
    });

    return List<Map<String, dynamic>>.from(response);
  }

  /// Loads SLA policy details along with related entities.
  ///
  /// This includes:
  /// - Tags
  /// - Ticket types (version-dependent)
  /// - Customers
  /// - Excluded stages
  @override
  Future<List<Map<String, dynamic>>> loadPolicyData(int policyId) async {
    final prefs = await SharedPreferences.getInstance();
    int version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;

    try {
      // Odoo 20 keeps priority, tags and customers in one `criteria_domain`.
      final criteriaAsDomain = await SlaCriteria.storedAsDomain();
      final fields = [
        'id',
        'name',
        'description',
        'team_id',
        if (criteriaAsDomain) ...[
          SlaCriteria.domainField,
        ] else ...[
          'priority',
          'tag_ids',
          'partner_ids',
        ],
        'stage_id',
        'time',
        'exclude_stage_ids',
        'ticket_count',
        'active',
      ];
      if (version <= 17) {
        fields.add('ticket_type_ids');
      }
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', policyId],
          ],
        ],
        'kwargs': {
          'fields': fields,
          'order': 'name asc',
          'context': {'active_test': false},
        },
      });

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );

      for (var json in data) {
        if (criteriaAsDomain) SlaCriteria.expand(json);
        // Read with `active_test: false` so an archived policy opens, the ticket
        // count would include archived tickets; Odoo's form does not.
        json.addAll(
          await OdooRecordCounts.read('helpdesk.sla', policyId, [
            'ticket_count',
          ]),
        );
        final tags = await fetchNames('helpdesk.tag', json['tag_ids'] ?? []);
        final types = (version <= 17)
            ? await fetchNames(
                'helpdesk.ticket.type',
                json['ticket_type_ids'] ?? [],
              )
            : <Map<String, dynamic>>[];
        final customers = await fetchNames(
          'res.partner',
          json['partner_ids'] ?? [],
        );
        final excludeStages = await fetchNames(
          'helpdesk.stage',
          json['exclude_stage_ids'] ?? [],
        );

        json['tags'] = tags;
        json['types'] = types;
        json['customers'] = customers;
        json['excludeStages'] = excludeStages;
      }

      return data;
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      throw errorMsg;
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('connection refused')) {
        throw {
          'title': 'Connection Refused',
          'description':
              'Please contact your administrator to restart the server.',
        };
      }

      if (errorText.contains('connection failed') ||
          errorText.contains('network is unreachable')) {
        throw {
          'title': 'Network Error',
          'description':
              'Please check your network connection and restart after enabling it.',
        };
      }
      throw {
        'title': 'Something went wrong',
        'description': 'Error fetching sla policy, Please try again later.',
      };
    }
  }

  /// Loads all helpdesk teams.
  @override
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name', 'display_name'],
          'order': 'name asc',
        },
      });

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      throw 'Error fetching team';
    }
  }

  /// Loads ticket types.
  @override
  Future<List<Map<String, dynamic>>> loadTypes() async {
    try {
      // Ticket types only exist up to Odoo 17; later servers have no such model.
      final prefs = await SharedPreferences.getInstance();
      final version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;
      if (version > 17) return [];

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket.type',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      throw 'Error fetching team';
    }
  }

  /// Loads available tags.
  @override
  Future<List<Map<String, dynamic>>> loadTags() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.tag',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      throw 'Error fetching team';
    }
  }

  /// Loads customers (partners).
  @override
  Future<List<Map<String, dynamic>>> loadCustomers() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      throw 'Error fetching team';
    }
  }

  /// Loads reachable stages excluding selected ones.
  @override
  Future<List<Map<String, dynamic>>> loadReachStages(
    int teamId,
    List excludeStageIds,
  ) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.stage',
        'method': 'search_read',
        'args': [
          [
            ['team_ids', '=', teamId],
            ['id', 'not in', excludeStageIds],
          ],
        ],
        'kwargs': {
          // Pipeline order, and `fold` so a default target can be picked.
          'fields': ['id', 'name', 'fold'],
          'order': 'sequence asc, id asc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Error fetching reach stages';
    }
  }

  /// Loads stages excluding a specific stage.
  @override
  Future<List<Map<String, dynamic>>> loadExcludingStages(
    int teamId,
    int? stageId,
  ) async {
    try {
      final domain = [
        ['team_ids', '=', teamId],
        if (stageId != null) ['id', '!=', stageId],
      ];

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.stage',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Error fetching excluding stages';
    }
  }

  /// The fields of [data] - and the criteria, in the form this server keeps
  /// them - that `helpdesk.sla` has on this server.
  Future<Set<String>> _slaFieldsIn(
    Map<String, dynamic> data,
    bool criteriaAsDomain,
  ) async => (await OdooFieldResolver.availableFields(
    'helpdesk.sla',
    {...data.keys, if (criteriaAsDomain) SlaCriteria.domainField}.toList(),
  )).toSet();

  /// Creates a new SLA policy.
  @override
  Future<void> createPolicy(Map<String, dynamic> data) async {
    try {
      final criteriaAsDomain = await SlaCriteria.storedAsDomain();
      final values = SlaPolicyValues.prepare(
        data,
        criteriaAsDomain: criteriaAsDomain,
        validFields: await _slaFieldsIn(data, criteriaAsDomain),
      );
      // A new policy always starts as "Match all records", never unset.
      if (criteriaAsDomain) {
        final stored = values[SlaCriteria.domainField];
        if (stored is! String || stored.trim().isEmpty) {
          values[SlaCriteria.domainField] = '[]';
        }
      }
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'create',
        'args': [values],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw errorMsg.toString();
    } on SlaCriteriaException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Error creating ticket';
    }
  }

  /// Updates an existing SLA policy.
  @override
  Future<void> updatePolicy(int id, Map<String, dynamic> data) async {
    try {
      final criteriaAsDomain = await SlaCriteria.storedAsDomain();
      final validFields = await _slaFieldsIn(data, criteriaAsDomain);

      // What the policy holds now: the criteria clauses the form does not own
      // must survive the save, and only what was edited is written.
      final stored = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'read',
        'args': [
          [id],
          validFields.toList(),
        ],
        'kwargs': {
          'context': {'active_test': false},
        },
      });
      final current = stored is List && stored.isNotEmpty
          ? Map<String, dynamic>.from(stored.first as Map)
          : <String, dynamic>{};

      final values = SlaPolicyValues.prepare(
        data,
        criteriaAsDomain: criteriaAsDomain,
        validFields: validFields,
        current: current,
      );
      if (values.isEmpty) return; // nothing was edited

      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'write',
        'args': [
          [id],
          values,
        ],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw errorMsg.toString();
    } on SlaCriteriaException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Error updating ticket';
    }
  }
}
