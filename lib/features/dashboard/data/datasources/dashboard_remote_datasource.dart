import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/api_validation_error.dart';
import '../../domain/entities/rating_entity.dart';
import '../models/dashboard_model.dart';
import '../models/rating_model.dart';

/// Remote datasource responsible for all Dashboard-related API operations.
///
/// This includes:
/// - Loading dashboard summary data
/// - Fetching helpdesk team statistics
/// - Managing ratings (list, filter, delete)
/// - Updating user/team-related fields in Odoo backend
abstract class DashboardRemoteDatasource {
  Future<Map<String, dynamic>> loadDashboard();

  Future<void> updateTarget(int teamId, String field, dynamic value);

  Future<Map<String, dynamic>> loadRatings({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,
    List<dynamic>? customDomain,
  });

  Future<void> deleteRating(int id);
}

/// Implementation of [DashboardRemoteDatasource] using Odoo RPC.
class DashboardRemoteDatasourceImpl implements DashboardRemoteDatasource {
  /// Extracts major version number from Odoo server version string.
  ///
  /// Example:
  /// "18.0+e" → 18

  int parseMajorVersion(String serverVersion) {
    // ignore: deprecated_member_use
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks whether the current user has admin/system access rights.
  ///
  /// Uses Odoo `helpdesk.group_helpdesk_manager` to validate permissions.
  Future<bool> checkAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    Future<bool> hasGroup(String groupExtId) async {
      if (majorVersion >= 18) {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [userId, groupExtId],
              'kwargs': {},
            }) ==
            true;
      } else {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [groupExtId],
              'kwargs': {},
            }) ==
            true;
      }
    }

    return await hasGroup('helpdesk.group_helpdesk_manager');
  }

  /// Loads dashboard data including:
  /// - Helpdesk dashboard summary
  /// - Team statistics (if user has access)
  ///
  /// Returns:
  /// Map containing dashboard model and team list.
  @override
  Future<Map<String, dynamic>> loadDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String version = prefs.getString('serverVersion') ?? '0';
      final int userId = prefs.getInt('userId') ?? 0;
      final int majorVersion = parseMajorVersion(version);

      bool isAccess = false;
      if (majorVersion >= 18) {
        isAccess =
            await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [userId, 'helpdesk.group_helpdesk_manager'],
              'kwargs': {},
            }) ==
            true;
      } else {
        isAccess =
            await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': ['helpdesk.group_helpdesk_manager'],
              'kwargs': {},
            }) ==
            true;
      }

      List<Map<String, dynamic>> teams = [];
      if (isAccess) {
        final response = await CompanySessionManager.callKwWithCompany({
          'model': 'helpdesk.team',
          'method': 'search_read',
          'args': [[]],
          'kwargs': {
            'fields': [
              'id',
              'name',
              'display_name',
              'ticket_closed',
              'success_rate',
              'rating_avg',
              'open_ticket_count',
              'unassigned_tickets',
              'urgent_ticket',
              'sla_failed',
            ],
            'order': 'name asc',
          },
        });
        teams = List<Map<String, dynamic>>.from(response);
      }

      final dashboardData = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'retrieve_dashboard',
        'args': [],
      });

      final dashboardJson = {"dashboardData": dashboardData, 'teams': teams};

      final dashboard = DashboardModel.fromJson(dashboardJson);

      return {
        "data": [dashboard],
      };
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      throw errorMsg;
    } catch (e) {
      // The generic message below hides the cause; log it.
      AppLogger.warning('Dashboard fetch failed: $e');
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
        'description': 'Error fetching dashboard, Please try again later.',
      };
    }
  }

  /// Updates a field value for a specific target (user/team).
  @override
  Future<void> updateTarget(int teamId, String field, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    final int? userId = prefs.getInt('userId');
    await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [userId],
        {field: value},
      ],
    });
  }

  /// Loads rating records with support for:
  /// - Pagination (limit/offset)
  /// - Search
  /// - Filters (status, date range, etc.)
  /// - Custom domain filters
  ///
  /// Returns:
  /// Map containing list of ratings and total count.
  @override
  Future<Map<String, dynamic>> loadRatings({
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
    final int? userId = prefs.getInt('userId');

    try {
      List domain = [
        ['res_model', '=', 'helpdesk.ticket'],
        ['consumed', '=', true],
      ];
      if (search != null && search.trim().isNotEmpty) {
        domain.add(['res_name', 'ilike', search]);
      }
      if (customDomain != null && customDomain.isNotEmpty) {
        domain.addAll(customDomain);
      }
      if (filters != null && filters.isNotEmpty) {
        for (var f in filters) {
          switch (f) {
            case 'my_ratings':
              domain.add([
                'rated_partner_id.user_ids',
                'in',
                [userId],
              ]);
              break;
            case 'satisfies':
              domain.add(['rating_text', '=', "top"]);
              break;

            case 'okay':
              domain.add(['rating_text', '=', "ok"]);
              break;

            case 'dis_satisfied':
              domain.add(['rating_text', '=', "ko"]);
              break;

            case 'today':
              domain.add([
                'create_date',
                '>',
                DateTime.now()
                    .subtract(const Duration(days: 7))
                    .toIso8601String(),
              ]);
              break;

            case 'last_7_days':
              domain.add([
                'create_date',
                '>=',
                DateTime.now()
                    .subtract(const Duration(days: 30))
                    .toIso8601String(),
              ]);
              break;

            case 'last_30_days':
              domain.add([
                'create_date',
                '>=',
                DateTime.now()
                    .subtract(const Duration(days: 30))
                    .toIso8601String(),
              ]);
              break;
          }
        }
      }

      if (selectedDates != null && selectedDates.isNotEmpty) {
        selectedDates.forEach((techKey, selectedDate) {
          if (techKey == 'submitted_date') {
            final dateStr = selectedDate.toIso8601String().split('T')[0];

            domain.add(['create_date', '>=', '$dateStr 00:00:00']);
            domain.add(['create_date', '<=', '$dateStr 23:59:59']);
          }
        });
      }

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'rating.rating',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'rated_partner_id',
            'partner_id',
            'parent_res_name',
            'res_id',
            'res_name',
            'rating_text',
            'create_date',
          ],
          'limit': limit,
          'offset': offset,
          'order': 'id desc',
        },
      });
      final totalCount = await CompanySessionManager.callKwWithCompany({
        'model': 'rating.rating',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      final List data = response;

      List<RatingEntity> ratings = [];

      for (var json in data) {
        ratings.add(RatingModel.fromJson(json));
      }

      return {"data": ratings, "total": totalCount};
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
        'description': 'Error fetching ratings, Please try again later.',
      };
    }
  }

  /// Deletes a rating by ID from the backend.
  @override
  Future<void> deleteRating(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'rating.rating',
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
