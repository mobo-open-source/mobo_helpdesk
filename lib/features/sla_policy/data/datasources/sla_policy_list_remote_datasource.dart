import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/widgets/api_validation_error.dart';
import '../../domain/entities/sla_policy_entity.dart';
import '../models/sla_policy_model.dart';
import '../sla_criteria.dart';

/// Remote datasource implementation for SLA Policy list operations.
///
/// This class handles all network interactions with the Odoo backend
/// related to SLA policy management, including:
///
/// - Fetching paginated SLA policy lists with search and filters
/// - Loading related metadata (tags, partners, stages, ticket types)
/// - Archiving and unarchiving SLA policies
/// - Permanently deleting SLA policies
///
/// It communicates with the Odoo server via [CompanySessionManager]
/// and adapts API fields based on server version compatibility.
///
/// Key features:
/// - Supports pagination (limit/offset)
/// - Supports search across multiple fields
/// - Supports dynamic domain filtering
/// - Handles server version-specific field differences (v17 and below)
/// - Enriches raw policy data with related entities
///
/// Error Handling:
/// - Converts Odoo exceptions into user-friendly error messages
/// - Handles network-related failures with descriptive messages
/// - Provides fallback error responses for unexpected failures
///
/// Note:
/// This layer is purely responsible for data fetching and transformation.
/// Business logic should be handled in the repository/usecase layer.
abstract class SlaPolicyListRemoteDatasource {
  Future<Map<String, dynamic>> loadPolicies({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,

    List<dynamic>? customDomain,
  });

  Future<void> deletePolicy(int id);

  Future<void> archivePolicy(int id);

  Future<void> unArchivePolicy(int id);
}

class SlaPolicyListRemoteDatasourceImpl
    implements SlaPolicyListRemoteDatasource {
  Future<List<Map<String, dynamic>>> fetchNames(String model, List ids) async {
    if (ids.isEmpty) return [];

    final response = await CompanySessionManager.callKwWithCompany({
      'model': model,
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', ids],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });

    return List<Map<String, dynamic>>.from(response);
  }

  /// Loads SLA policies from the backend with pagination, search, and filters.
  ///
  /// This method fetches SLA policy records from the Odoo server using
  /// `search_read` and also retrieves the total record count using
  /// `search_count` for pagination purposes.
  ///
  /// It supports:
  /// - Pagination using [limit] and [offset]
  /// - Full-text search on policy name, team name, and stage name
  /// - Custom domain filtering via [customDomain]
  /// - Predefined filters such as archived records
  /// - Server version-based field adaptation (e.g., ticket types for v17 and below)
  ///
  /// For each policy record, related data such as:
  /// - Ticket types
  /// - Tags
  /// - Partners
  /// - Excluded stages
  /// are fetched and mapped into the final [SlaPolicyEntity].
  ///
  /// Returns a map containing:
  /// - `data`: List of [SlaPolicyEntity]
  /// - `total`: Total number of matching records
  ///
  /// Throws:
  /// - Parsed Odoo-specific errors via `extractOdooError`
  /// - Network-related or generic error maps with title and description
  @override
  Future<Map<String, dynamic>> loadPolicies({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,

    List<dynamic>? customDomain,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    int version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;

    try {
      List domain = [];

      if (search != null && search.trim().isNotEmpty) {
        domain = [
          '|',
          '|',
          ['name', 'ilike', search],
          ['team_id.name', 'ilike', search],
          ['stage_id.name', 'ilike', search],
        ];
      }

      if (customDomain != null && customDomain.isNotEmpty) {
        domain.addAll(customDomain);
      }

      if (filters != null && filters.isNotEmpty) {
        for (var f in filters) {
          switch (f) {
            case 'archive':
              domain.add(['active', '=', false]);
              break;
          }
        }
      }

      // Odoo 20 keeps priority, tags and customers in one `criteria_domain`.
      final criteriaAsDomain = await SlaCriteria.storedAsDomain();
      final fields = [
        'id',
        'name',
        'team_id',
        'stage_id',
        'time',
        'description',
        'exclude_stage_ids',
        if (criteriaAsDomain)
          SlaCriteria.domainField
        else ...[
          'priority',
          'tag_ids',
          'partner_ids',
        ],
      ];
      if (version <= 17) {
        fields.add('ticket_type_ids');
      }
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': fields,
          'limit': limit,
          'offset': offset,
          'order': 'id desc',
        },
      });
      final totalCount = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      final List data = response;

      List<SlaPolicyEntity> slaPolicies = [];

      for (var json in data) {
        if (criteriaAsDomain) SlaCriteria.expand(json);
        final ticketTypes = (version <= 17)
            ? await fetchNames(
                'helpdesk.ticket.type',
                json['ticket_type_ids'] ?? [],
              )
            : <Map<String, dynamic>>[];

        final tags = await fetchNames('helpdesk.tag', json['tag_ids'] ?? []);

        final partners = await fetchNames(
          'res.partner',
          json['partner_ids'] ?? [],
        );

        final excludingStages = await fetchNames(
          'helpdesk.stage',
          json['exclude_stage_ids'] ?? [],
        );

        slaPolicies.add(
          SlaPolicyModel.fromJson(
            json,
            types: ticketTypes,
            tags: tags,
            partners: partners,
            excludingStages: excludingStages,
          ),
        );
      }

      return {"data": slaPolicies, "total": totalCount};
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
        'description': 'Error fetching sla policies, Please try again later.',
      };
    }
  }

  /// Archives (soft deletes) an SLA policy by setting its `active` field to false.
  ///
  /// This method updates the `helpdesk.sla` record in Odoo to mark it as archived
  /// instead of permanently deleting it.
  ///
  /// Parameters:
  /// - [id]: The ID of the SLA policy to archive.
  ///
  /// Throws:
  /// - A user-friendly error message extracted from Odoo exceptions
  /// - "Archive failed" for unexpected errors
  @override
  Future<void> archivePolicy(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'write',
        'args': [
          [id],
          {'active': false},
        ],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw errorMsg.toString();
    } catch (e) {
      throw "Archive failed";
    }
  }

  /// Restores an archived SLA policy by setting its `active` field to true.
  ///
  /// This method reactivates a previously archived SLA policy in the backend.
  ///
  /// Parameters:
  /// - [id]: The ID of the SLA policy to unarchive.
  ///
  /// Throws:
  /// - A user-friendly error message extracted from Odoo exceptions
  /// - "Un Archive failed" for unexpected errors
  @override
  Future<void> unArchivePolicy(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'write',
        'args': [
          [id],
          {'active': true},
        ],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw errorMsg.toString();
    } catch (e) {
      throw "Un Archive failed";
    }
  }

  /// Permanently deletes an SLA policy from the backend.
  ///
  /// This method calls the Odoo `unlink` operation to remove the record
  /// completely from the `helpdesk.sla` model.
  ///
  /// Parameters:
  /// - [id]: The ID of the SLA policy to delete.
  ///
  /// Throws:
  /// - A user-friendly error message extracted from Odoo exceptions
  /// - "Delete failed" for unexpected errors
  @override
  Future<void> deletePolicy(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.sla',
        'method': 'unlink',
        'args': [
          [id],
        ],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw errorMsg.toString();
    } catch (e) {
      throw "Delete failed";
    }
  }
}
