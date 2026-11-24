import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../../../core/session/company_session_manager.dart';
import '../../../../core/widgets/api_validation_error.dart';
import '../../domain/entities/team_entity.dart';
import '../models/team_model.dart';

/// Remote datasource contract for managing Helpdesk Teams list operations.
///
/// Defines all backend interactions required for:
/// - Fetching paginated team lists with search and filters
/// - Archiving and unarchiving teams
/// - Deleting teams from the system
///
/// This abstraction allows separation between domain layer and Odoo RPC implementation.
abstract class TeamListRemoteDatasource {
  Future<Map<String, dynamic>> loadTeams({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
  });

  Future<void> deleteTeam(int id);

  Future<void> archiveTeam(int id);

  Future<void> unArchiveTeam(int id);
}

/// Implementation of [TeamListRemoteDatasource].
///
/// Communicates with Odoo backend using [CompanySessionManager]
/// to perform CRUD operations on `helpdesk.team` model.
///
/// Handles:
/// - Pagination and search queries
/// - Filtering (e.g., archived teams)
/// - Archive/unarchive actions
/// - Team deletion
///
/// Converts raw API responses into domain [TeamEntity] objects.
class TeamListRemoteDatasourceImpl implements TeamListRemoteDatasource {
  /// Fetches a paginated list of Helpdesk Teams from the backend.
  ///
  /// Supports:
  /// - Pagination via [limit] and [offset]
  /// - Full-text search via [search]
  /// - Filtering (e.g., archived teams via [filters])
  ///
  /// Returns a map containing:
  /// - `data`: List of [TeamEntity]
  /// - `total`: Total number of matching records
  ///
  /// Throws:
  /// - Structured error map on Odoo or network failure
  @override
  Future<Map<String, dynamic>> loadTeams({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,
  }) async {
    try {
      List domain = [];

      if (search != null && search.trim().isNotEmpty) {
        domain = [
          ['name', 'ilike', search],
        ];
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

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'alias_email', 'alias_name', 'company_id'],
          'limit': limit,
          'offset': offset,
          'order': 'id desc',
        },
      });
      final totalCount = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      final List data = response;

      List<TeamEntity> teams = [];

      for (var json in data) {
        teams.add(TeamModel.fromJson(json));
      }

      return {"data": teams, "total": totalCount};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      throw errorMsg;
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (e is NoInternetException ||
          e is ServerUnreachableException ||
          errorText.contains('socketexception') ||
          errorText.contains('clientexception') ||
          errorText.contains('timeout')) {
        throw {
          'title': 'Network Error',
          'description': 'Please check your network connection and try again.',
        };
      }
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
        'description': 'Error fetching teams, Please try again later.',
      };
    }
  }

  /// Archives a Helpdesk Team by setting `active = false`.
  ///
  /// This hides the team from active views without deleting it.
  @override
  Future<void> archiveTeam(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
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

  /// Restores an archived Helpdesk Team by setting `active = true`.
  @override
  Future<void> unArchiveTeam(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
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

  /// Permanently deletes a Helpdesk Team from the backend.
  ///
  /// Uses Odoo `unlink` method.
  /// This action cannot be undone.
  @override
  Future<void> deleteTeam(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
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
