import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/odoo_record_counts.dart';
import '../../../../core/widgets/api_validation_error.dart';

abstract class TicketFormRemoteDataSource {
  Future<List<Map<String, dynamic>>> loadTicketData(int id);

  Future<List<Map<String, dynamic>>> loadHelpdeskTeam();

  Future<List<Map<String, dynamic>>> loadUsers();

  Future<List<Map<String, dynamic>>> loadTypes();

  Future<List<Map<String, dynamic>>> loadTags();

  Future<List<Map<String, dynamic>>> loadPartners();

  Future<List<Map<String, dynamic>>> loadStages();

  Future<List<Map<String, dynamic>>> loadSalesTeam();

  Future<void> createTicket(Map<String, dynamic> data);

  Future<void> updateTicket(int id, Map<String, dynamic> data);

  Future<void> convertOpportunity(Map<String, dynamic> data);
}

class TicketFormRemoteDataSourceImpl implements TicketFormRemoteDataSource {
  /// Fetches related records (names) for Many2many/Many fields.
  ///
  /// Depending on the model, it dynamically selects fields:
  /// - `helpdesk.sla.status` → id, display_name, color
  /// - `mail.activity` → id, display_name
  /// - `helpdesk.tag` → id, name, color
  /// - others → id, name
  ///
  /// Returns a list of mapped records for the given IDs.
  Future<List<Map<String, dynamic>>> fetchNames(String model, List ids) async {
    if (ids.isEmpty) return [];

    final fields = model == 'helpdesk.sla.status'
        ? ['id', 'display_name', 'color']
        : model == 'mail.activity'
        ? [
            'id',
            'display_name',
            'user_id',
            'activity_type_id',
            'date_deadline',
            'icon',
            'summary',
            'note',
          ]
        : model == 'helpdesk.tag'
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

  /// Loads full ticket details for a given ticket ID.
  ///
  /// This includes:
  /// - Ticket core fields (name, team, user, stage, priority, etc.)
  /// - Conditional fields based on server version (e.g. ticket_type_id)
  /// - Related data expansion:
  ///   - tags
  ///   - activities
  ///   - SLA statuses
  ///
  /// Returns a list containing a single ticket map with enriched relational data.
  @override
  Future<List<Map<String, dynamic>>> loadTicketData(int ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    int version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;

    try {
      final fields = [
        'id',
        'name',
        'team_id',
        'sla_ids',
        'properties',
        'user_id',
        'priority',
        'tag_ids',
        'partner_id',
        'partner_phone',
        'description',
        'activity_ids',
        'sla_deadline',
        'stage_id',
        'sla_status_ids',
        'kanban_state',
        'create_date',
        'partner_open_ticket_count',
        'partner_ticket_count',
        'partner_ticket_ids',
        'active',
      ];
      if (version <= 17) {
        fields.add('ticket_type_id');
      }
      // Odoo 20 has no `email_cc` on tickets.
      if (await OdooFieldResolver.hasField('helpdesk.ticket', 'email_cc')) {
        fields.add('email_cc');
      }

      final crmCount = await CompanySessionManager.callKwWithCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            ['name', '=', 'crm'],
            ['state', '=', 'installed'],
          ],
        ],
        'kwargs': {},
      });

      final bool isCrmInstalled = crmCount > 0;

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', ticketId],
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
        final tags = await fetchNames('helpdesk.tag', json['tag_ids'] ?? []);
        final activities = await fetchNames(
          'mail.activity',
          json['activity_ids'] ?? [],
        );
        final slaStatuses = await fetchNames(
          'helpdesk.sla.status',
          json['sla_status_ids'] ?? [],
        );

        json['tags'] = tags;
        json['activities'] = activities;
        json['sla_statuses'] = slaStatuses;
        json['is_crm'] = isCrmInstalled;
      }

      // The ticket is read with `active_test: false` so an archived one opens,
      // which would count the customer's archived tickets too. Odoo's form does
      // not, so these are read without that context.
      final counts = await OdooRecordCounts.read('helpdesk.ticket', ticketId, [
        'partner_ticket_count',
        'partner_open_ticket_count',
        'partner_ticket_ids',
      ]);
      for (final json in data) {
        json.addAll(counts);
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
        'description': 'Error fetching ticket, Please try again later.',
      };
    }
  }

  /// Fetches all helpdesk teams from the server.
  ///
  /// Returns a list of teams with:
  /// - id
  /// - name
  ///
  /// Used for dropdowns or assignment selection.
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

  /// Fetches all system users.
  ///
  /// Returns a list of users with:
  /// - id
  /// - name
  ///
  /// Used for assigning tickets or filtering.
  @override
  Future<List<Map<String, dynamic>>> loadUsers() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
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

  /// Fetches available ticket types from the helpdesk system.
  ///
  /// Returns a list of ticket types with:
  /// - id
  /// - name
  ///
  /// Used for categorizing tickets.
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

  /// Fetches all available helpdesk tags.
  ///
  /// Returns a list of tags with:
  /// - id
  /// - name
  ///
  /// Used for tagging tickets.
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

  /// Fetches all partners (customers/contacts).
  ///
  /// Returns a list of partners with:
  /// - id
  /// - name
  ///
  /// Used for linking tickets to customers.
  @override
  Future<List<Map<String, dynamic>>> loadPartners() async {
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

  /// Fetches Helpdesk stages used for ticket workflow configuration.
  ///
  /// Returns stages ordered alphabetically by name.
  @override
  Future<List<Map<String, dynamic>>> loadStages() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.stage',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name', 'sequence'],
          'order': 'sequence asc',
        },
      });

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Error fetching team: $e');
    }
  }

  /// Fetches sales team used for convert to opportunity workflow configuration.
  ///
  /// Returns sales team ordered alphabetically by name.
  @override
  Future<List<Map<String, dynamic>>> loadSalesTeam() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'crm.team',
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
      throw Exception('Error fetching team: $e');
    }
  }

  /// Creates a new helpdesk ticket.
  ///
  /// Sends the provided ticket data to the server.
  /// Throws an error message if creation fails.
  @override
  Future<void> createTicket(Map<String, dynamic> data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw errorMsg.toString();
    } catch (e) {
      throw 'Error creating ticket';
    }
  }

  /// Updates an existing helpdesk ticket.
  ///
  /// Sends updated fields for the given ticket ID.
  /// Throws an error message if update fails.
  @override
  Future<void> updateTicket(int id, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('tag_ids')) {
        final tags = data['tag_ids'];

        data['tag_ids'] = (tags is List && tags.isNotEmpty)
            ? [
                [6, 0, tags],
              ]
            : [
                [5, 0, 0],
              ];
      }
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
        'method': 'write',
        'args': [
          [id],
          data,
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
      throw 'Error updating ticket';
    }
  }

  /// Convert to opportunity of an existing helpdesk ticket.
  ///
  /// Sends updated values for the given ticket ID.
  /// Throws an error message if update fails.
  @override
  Future<void> convertOpportunity(Map<String, dynamic> data) async {
    try {
      final lead = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket.to.lead',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket.to.lead',
        'method': 'action_convert_to_lead',
        'args': [
          [lead],
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
      throw 'Error updating ticket';
    }
  }
}
