import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/widgets/api_validation_error.dart';
import '../../domain/entities/ticket_entity.dart';
import '../models/ticket_model.dart';

abstract class TicketListRemoteDatasource {
  Future<Map<String, dynamic>> loadTickets({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,

    List<dynamic>? customDomain,
  });

  Future<List<Map<String, dynamic>>> loadStages();

  Future<List<Map<String, dynamic>>> loadUsers();

  Future<List<Map<String, dynamic>>> loadActivityTypes();

  /// Roles an activity can be assigned to instead of a person. Empty on servers
  /// that have no activity roles (before Odoo 20).
  Future<List<Map<String, dynamic>>> loadActivityRoles();

  /// What Odoo fills in for a new activity of [activityTypeId] on the ticket:
  /// summary, due date, assignee, role, note and phone. With no type given, the
  /// type Odoo would preselect is used. Best effort: an empty map when the
  /// server cannot say.
  Future<Map<String, dynamic>> loadActivityDefaults({
    required int ticketId,
    int? activityTypeId,
    Map<String, dynamic> current = const {},
  });

  Future<void> deleteTicket(int id);

  /// Permanently deletes a helpdesk stage.
  Future<void> deleteStage(int id);

  Future<void> archiveTicket(int id);

  Future<void> unArchiveTicket(int id);

  Future<Map<String, dynamic>> getStage(int id);

  Future<List<Map<String, dynamic>>> loadEmailTemplate(int id);

  Future<List<Map<String, dynamic>>> loadSmsTemplate(int id);

  Future<void> updateStage(
    dynamic stageId,
    String newName,
    dynamic emailTemplate,
    dynamic smsTemplate,
    int? sequence,
  );

  Future<List<Map<String, dynamic>>> loadTicketData(int id);

  Future<void> scheduleActivity(Map<String, dynamic> data);

  Future<void> updateActivity(int id, Map<String, dynamic> data);

  Future<void> markDoneActivity(int id);

  Future<void> moveTicketToStage(int ticketId, int stageId);
}

List buildOr(List conditions) {
  if (conditions.isEmpty) return [];
  if (conditions.length == 1) return conditions;

  return [...List.filled(conditions.length - 1, '|'), ...conditions];
}

List buildFilterDomain({required List<String>? filters, required int? userId}) {
  List assignment = [];
  List priority = [];
  List sla = [];
  List stage = [];
  List rating = [];
  List others = [];

  for (var f in filters ?? []) {
    switch (f) {
      /// Assignment (OR)
      case 'my_tickets':
        assignment.add(['user_id', '=', userId]);
        break;

      case 'follow':
        assignment.add(['message_is_follower', '=', true]);
        break;

      case 'un_assign':
        assignment.add(['user_id', '=', false]);
        break;

      /// Priority (OR)
      case 'urgent':
        priority.add(['priority', '=', '3']);
        break;

      case 'high_priority':
        priority.add(['priority', '=', '2']);
        break;

      case 'medium_priority':
        priority.add(['priority', '=', '1']);
        break;

      case 'low_priority':
        priority.add(['priority', '=', '0']);
        break;

      /// SLA (OR)
      case 'sla_success':
        sla.add(['sla_success', '=', true]);
        break;

      case 'sla_progress':
        sla.add(['sla_status_ids.status', '=', 'ongoing']);
        break;

      case 'sla_fail':
        sla.add(['sla_fail', '=', true]);
        break;

      /// Stage (OR)
      case 'open_stage':
        stage.add(['stage_id.fold', '=', false]);
        break;

      case 'closed_stage':
        stage.add(['stage_id.fold', '=', true]);
        break;

      /// Rating (OR)
      case 'satisfied':
        rating.add(['rating_avg', '>', 3.66]);
        break;

      case 'okay':
        rating.addAll([
          ['rating_avg', '<', 3.66],
          ['rating_avg', '>=', 2.33],
        ]);
        break;

      case 'dis_satisfied':
        rating.add(['rating_avg', '<', 2.33]);
        break;

      /// Others (AND)
      case 'archive':
        others.add(['active', '=', false]);
        break;

      case 'closed_7_days':
        others.add([
          'write_date',
          '>=',
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        ]);
        break;

      case 'closed_30_days':
        others.add([
          'write_date',
          '>=',
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        ]);
        break;
    }
  }

  final groups = [
    buildOr(assignment),
    buildOr(priority),
    buildOr(sla),
    buildOr(stage),
    buildOr(rating),
    others,
  ];

  final validGroups = groups.where((g) => g.isNotEmpty).toList();

  if (validGroups.isEmpty) return [];

  List finalDomain = validGroups.first;

  for (int i = 1; i < validGroups.length; i++) {
    finalDomain = ['&', ...finalDomain, ...validGroups[i]];
  }

  return finalDomain;
}

class TicketListRemoteDatasourceImpl implements TicketListRemoteDatasource {
  /// Fetches related display data (Many2many / Many2one relations)
  /// for a given model and list of IDs.
  ///
  /// The returned fields depend on the model:
  /// - `helpdesk.sla.status`, `mail.activity` → id, display_name
  /// - `helpdesk.tag` → id, name, color
  /// - `helpdesk.stage` → id, name, sequence
  /// - default → id, name
  ///
  /// Returns a list of mapped records.
  Future<List<Map<String, dynamic>>> fetchNames(String model, List ids) async {
    if (ids.isEmpty) return [];

    // Every version has these on an activity.
    const activityCore = [
      'id',
      'display_name',
      'user_id',
      'activity_type_id',
      'date_deadline',
      'icon',
      'summary',
      'note',
    ];

    final fields = model == 'mail.activity'
        ? [
            ...activityCore,
            // Odoo 20 adds a role to assign to and a phone number for calls,
            // and the type's category is there from 17. When the server cannot
            // be asked, the newer two are taken to be absent: leaving them out
            // costs nothing, asking an older server for one fails the request.
            for (final extra in const ['role_id', 'phone', 'activity_category'])
              if (await OdooFieldResolver.hasField(
                'mail.activity',
                extra,
                assumeIfUnknown: extra == 'activity_category',
              ))
                extra,
          ]
        : model == 'helpdesk.sla.status'
        ? ['id', 'display_name']
        : model == 'helpdesk.tag'
        ? ['id', 'name', 'color']
        : model == 'helpdesk.stage'
        ? ['id', 'name', 'sequence']
        : ['id', 'name'];

    Future<dynamic> read(List<String> names) =>
        CompanySessionManager.callKwWithCompany({
          'model': model,
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', ids],
            ],
          ],
          'kwargs': {'fields': names},
        });

    dynamic response;
    try {
      response = await read(fields);
    } on OdooException {
      // The extra activity fields only enrich the list. If the server rejects
      // one, the activities still load without it rather than the whole
      // ticket list failing.
      if (model != 'mail.activity' || fields.length == activityCore.length) {
        rethrow;
      }
      response = await read(activityCore);
    }

    return List<Map<String, dynamic>>.from(response);
  }

  /// Loads paginated helpdesk tickets with filtering, search, and grouping support.
  ///
  /// Supports:
  /// - Search by name, SLA deadline, or stage name
  /// - Filters (priority, assignment, SLA status, archive, etc.)
  /// - Custom domain injection
  /// - Date-based filtering (create_date)
  /// - Version-based field adjustments (ticket_type_id for older servers)
  ///
  /// Returns:
  /// - `data`: List of [TicketEntity]
  /// - `total`: Total matching record count
  @override
  Future<Map<String, dynamic>> loadTickets({
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
    int version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;

    try {
      List domain = [];

      if (search != null && search.trim().isNotEmpty) {
        domain = [
          '|',
          '|',
          ['name', 'ilike', search],
          ['sla_deadline', 'ilike', search],
          ['stage_id.name', 'ilike', search],
        ];
      }

      if (customDomain != null && customDomain.isNotEmpty) {
        domain.addAll(customDomain);
      }

      if (filters != null && filters.isNotEmpty) {
        final filterDomain = buildFilterDomain(
          filters: filters,
          userId: userId,
        );

        domain.addAll(filterDomain);
      }

      if (selectedDates != null && selectedDates.isNotEmpty) {
        selectedDates.forEach((techKey, selectedDate) {
          if (techKey == 'create_date') {
            final dateStr = selectedDate.toIso8601String().split('T')[0];

            domain.add(['create_date', '>=', '$dateStr 00:00:00']);
            domain.add(['create_date', '<=', '$dateStr 23:59:59']);
          }
        });
      }
      final fields = [
        'id',
        'name',
        'team_id',
        'properties',
        'user_id',
        'priority',
        'tag_ids',
        'partner_id',
        'activity_ids',
        'sla_ids',
        'sla_status_ids',
        'sla_deadline',
        'stage_id',
        'kanban_state',
        'create_date',
        'activity_type_id',
        'activity_type_icon',
      ];
      if (version <= 17) {
        fields.add('ticket_type_id');
      }
      // The page and the count are independent, so they go out together.
      final results = await Future.wait([
        CompanySessionManager.callKwWithCompany({
          'model': 'helpdesk.ticket',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': fields,
            'limit': limit,
            'offset': offset,
            'order': 'id desc',
          },
        }),
        CompanySessionManager.callKwWithCompany({
          'model': 'helpdesk.ticket',
          'method': 'search_count',
          'args': [domain],
          'kwargs': {},
        }),
      ]);
      final List data = results[0];
      final totalCount = results[1];

      // One lookup per related model for the whole page, not one per ticket.
      Set<int> idsOf(String key) => {
        for (final json in data)
          if (json[key] is List)
            for (final id in json[key])
              if (id is int) id,
      };
      final stageIds = {
        for (final json in data)
          if (json['stage_id'] is List &&
              json['stage_id'].isNotEmpty &&
              json['stage_id'][0] is int)
            json['stage_id'][0] as int,
      };

      final related = await Future.wait([
        fetchNames('helpdesk.tag', idsOf('tag_ids').toList()),
        fetchNames('mail.activity', idsOf('activity_ids').toList()),
        fetchNames('helpdesk.sla.status', idsOf('sla_status_ids').toList()),
        fetchNames('helpdesk.stage', stageIds.toList()),
      ]);

      Map<int, Map<String, dynamic>> byId(List<Map<String, dynamic>> rows) => {
        for (final r in rows) r['id'] as int: r,
      };
      List<Map<String, dynamic>> pick(
        Map<int, Map<String, dynamic>> index,
        dynamic ids,
      ) => [
        if (ids is List)
          for (final id in ids)
            if (index[id] != null) index[id]!,
      ];

      final tagIndex = byId(related[0]);
      final activityIndex = byId(related[1]);
      final slaIndex = byId(related[2]);
      final stageIndex = byId(related[3]);

      final List<TicketEntity> tickets = [
        for (final json in data)
          TicketModel.fromJson(
            json,
            tags: pick(tagIndex, json['tag_ids']),
            activities: pick(activityIndex, json['activity_ids']),
            slaStatuses: pick(slaIndex, json['sla_status_ids']),
            stageData:
                (json['stage_id'] is List && json['stage_id'].isNotEmpty
                    ? stageIndex[json['stage_id'][0]]
                    : null) ??
                {},
          ),
      ];

      return {"data": tickets, "total": totalCount};
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
        'description': 'Error fetching tickets, Please try again later.',
      };
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
      // Portal and public users cannot be assigned work: Odoo offers internal
      // users only wherever a ticket, activity or lead is assigned.
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['share', '=', false],
          ],
        ],
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

  /// Fetches all activity types.
  ///
  /// Returns a list of users with:
  /// - id
  /// - name
  @override
  Future<List<Map<String, dynamic>>> loadActivityTypes() async {
    try {
      // `category` tells a phone call from the rest, which decides whether the
      // form asks for a phone number; `icon` is the badge Odoo draws.
      Future<dynamic> read(List<String> fields) =>
          CompanySessionManager.callKwWithCompany({
            'model': 'mail.activity.type',
            'method': 'search_read',
            'args': [
              [
                '|',
                ['res_model', '=', false],
                ['res_model', '=', 'helpdesk.ticket'],
              ],
            ],
            'kwargs': {'fields': fields, 'order': 'name asc'},
          });

      dynamic response;
      try {
        response = await read(['id', 'name', 'icon', 'category']);
      } on OdooException {
        response = await read(['id', 'name']);
      }

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      throw 'Error fetching activity types';
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadActivityRoles() async {
    // Activity roles are an Odoo 20 feature.
    if (!await OdooFieldResolver.hasField(
      'mail.activity',
      'role_id',
      assumeIfUnknown: false,
    )) {
      return [];
    }
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'res.role',
      'method': 'search_read',
      'args': [
        [
          ['user_ids', '!=', false],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name'],
        'order': 'name asc',
      },
    });
    return response is List ? List<Map<String, dynamic>>.from(response) : [];
  }

  @override
  Future<Map<String, dynamic>> loadActivityDefaults({
    required int ticketId,
    int? activityTypeId,
    Map<String, dynamic> current = const {},
  }) async {
    var typeId = activityTypeId;
    try {
      if (typeId == null) {
        // The type Odoo preselects when its own form opens.
        final preset = await CompanySessionManager.callKwWithCompany({
          'model': 'mail.activity',
          'method': 'default_get',
          'args': [
            ['activity_type_id'],
          ],
          'kwargs': {
            'context': {
              'default_res_model': 'helpdesk.ticket',
              'default_res_id': ticketId,
            },
          },
        });
        final id = preset is Map ? preset['activity_type_id'] : null;
        if (id is! int) return {};
        typeId = id;
      }
    } catch (_) {
      return {};
    }

    final defaults = <String, dynamic>{'activity_type_id': typeId};
    try {
      final hasRole = await OdooFieldResolver.hasField(
        'mail.activity',
        'role_id',
        assumeIfUnknown: false,
      );
      final hasPhone = await OdooFieldResolver.hasField(
        'mail.activity',
        'phone',
        assumeIfUnknown: false,
      );

      // Only fields the server has: one unknown name rejects the whole call.
      final spec = <String, dynamic>{
        'summary': {},
        'date_deadline': {},
        'user_id': {
          'fields': {'display_name': {}},
        },
        'note': {},
        if (hasRole)
          'role_id': {
            'fields': {'display_name': {}},
          },
        if (hasPhone) 'phone': {},
      };

      // The values already in the form go along, so Odoo applies its own rules
      // about what a type may overwrite (a type without a default summary
      // keeps the one typed, for instance).
      final values = <String, dynamic>{
        'res_model': 'helpdesk.ticket',
        'res_model_id': await _ticketModelId(),
        'res_id': ticketId,
        'activity_type_id': typeId,
        for (final key in spec.keys) key: current[key] ?? false,
      };

      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'onchange',
        // The leading [] is the (absent) record: this is a new activity.
        'args': [
          [],
          values,
          ['activity_type_id'],
          spec,
        ],
        'kwargs': {},
      });

      final changed = result is Map ? result['value'] : null;
      if (changed is Map) {
        for (final key in spec.keys) {
          if (!changed.containsKey(key)) continue;
          final value = changed[key];
          if (key == 'user_id' || key == 'role_id') {
            defaults[key] = _relationOf(value);
          } else {
            defaults[key] = value is String ? value : '';
          }
        }
      }
    } catch (_) {
      // The type alone still goes back; the form simply is not prefilled.
    }
    return defaults;
  }

  /// A many2one as the form uses it, `{id, name}`, from either shape Odoo sends:
  /// `{id, display_name}` (onchange) or `[id, name]` (read). `null` when empty.
  Map<String, dynamic>? _relationOf(dynamic value) {
    if (value is Map && value['id'] is int) {
      return {'id': value['id'], 'name': value['display_name'] ?? ''};
    }
    if (value is List && value.length >= 2 && value[0] is int) {
      return {'id': value[0], 'name': value[1]};
    }
    return null;
  }

  /// Archives (soft deletes) a ticket by setting active = false.
  @override
  Future<void> archiveTicket(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
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

  /// Restores an archived ticket by setting active = true.
  @override
  Future<void> unArchiveTicket(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
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

  /// Permanently deletes a ticket from the system.
  @override
  Future<void> deleteTicket(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
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

  /// Permanently deletes a helpdesk stage.
  @override
  Future<void> deleteStage(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.stage',
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

  /// Fetches email templates linked to helpdesk tickets.
  ///
  /// Returns a list of:
  /// - id
  /// - name
  @override
  Future<List<Map<String, dynamic>>> loadEmailTemplate(int stageId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mail.template',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'helpdesk.ticket'],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Error fetching countries';
    }
  }

  /// Fetches details of a specific helpdesk stage.
  ///
  /// Returns:
  /// - id
  /// - name
  /// - template_id
  /// - sms_template_id
  /// - sequence
  @override
  Future<Map<String, dynamic>> getStage(int stageId) async {
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'helpdesk.stage',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', stageId],
        ],
        ['name', 'template_id', 'sms_template_id', 'sequence'],
      ],
      'kwargs': {},
    });

    return response[0];
  }

  /// Fetches SMS templates linked to helpdesk tickets.
  ///
  /// Returns a list of:
  /// - id
  /// - name
  @override
  Future<List<Map<String, dynamic>>> loadSmsTemplate(int stageId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'sms.template',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'helpdesk.ticket'],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Error fetching countries';
    }
  }

  /// Updates a helpdesk stage.
  ///
  /// Allows updating:
  /// - name
  /// - email template
  /// - SMS template
  /// - sequence (optional)
  @override
  Future<void> updateStage(
    dynamic stageId,
    String newName,
    dynamic emailTemplate,
    dynamic smsTemplate,
    int? sequence,
  ) async {
    try {
      final data = <String, dynamic>{
        'name': newName.trim(),

        'template_id': emailTemplate != null && emailTemplate is Map
            ? emailTemplate['id']
            : false,

        'sms_template_id': smsTemplate != null && smsTemplate is Map
            ? smsTemplate['id']
            : false,

        if (sequence != null) 'sequence': sequence,
      };
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.stage',
        'method': 'write',
        'args': [
          [stageId],
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
      rethrow;
    }
  }

  /// Loads minimal ticket data for a specific ticket ID.
  ///
  /// Includes core fields like:
  /// - name, team, user, priority, tags
  /// - partner info, activity, SLA data
  /// - stage and kanban state
  ///
  /// Returns a list with a single ticket map.
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
      ];
      if (version <= 17) {
        fields.add('ticket_type_id');
      }
      // Odoo 20 has no `email_cc` on tickets.
      if (await OdooFieldResolver.hasField('helpdesk.ticket', 'email_cc')) {
        fields.add('email_cc');
      }
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', ticketId],
          ],
        ],
        'kwargs': {'fields': fields, 'order': 'name asc'},
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error fetching countries: $e');
    }
  }

  /// The `ir.model` id that an activity on a ticket points at.
  ///
  /// Odoo 20 lets only administrators read `ir.model`, so a helpdesk user asking
  /// for it directly is refused. `mail.activity.default_get` answers for any
  /// user, and has returned this id since long before Odoo 20; the direct read
  /// stays as the fallback for a server that does not.
  Future<int> _ticketModelId() async {
    try {
      final defaults = await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'default_get',
        'args': [
          ['res_model', 'res_model_id'],
        ],
        'kwargs': {
          'context': {'default_res_model': 'helpdesk.ticket'},
        },
      });
      final id = defaults is Map ? defaults['res_model_id'] : null;
      if (id is int) return id;
    } catch (_) {
      // Fall through to the direct read.
    }

    final modelData = await CompanySessionManager.callKwWithCompany({
      'model': 'ir.model',
      'method': 'search_read',
      'args': [
        [
          ['model', '=', 'helpdesk.ticket'],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name'],
        'limit': 1,
      },
    });
    return modelData[0]['id'];
  }

  @override
  Future<void> scheduleActivity(Map<String, dynamic> data) async {
    try {
      final resModelId = await _ticketModelId();
      data.addAll({'res_model': 'helpdesk.ticket', 'res_model_id': resModelId});

      await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      throw error['description'] ??
          'Something went wrong. Please try again later.';
    } catch (e) {
      throw 'Error scheduling activity';
    }
  }

  @override
  Future<void> updateActivity(int id, Map<String, dynamic> data) async {
    try {
      final resModelId = await _ticketModelId();
      data.addAll({'res_model': 'helpdesk.ticket', 'res_model_id': resModelId});

      await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'write',
        'args': [id, data],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      throw error['description'] ??
          'Something went wrong. Please try again later.';
    } catch (e) {
      throw 'Error scheduling activity';
    }
  }

  @override
  Future<void> markDoneActivity(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'action_done',
        'args': [
          [id],
        ],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      throw error['description'] ??
          'Something went wrong. Please try again later.';
    } catch (e) {
      throw 'Error done activity';
    }
  }

  @override
  Future<void> moveTicketToStage(int ticketId, int stageId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.ticket',
        'method': 'write',
        'args': [
          [ticketId],
          {'stage_id': stageId},
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
      rethrow;
    }
  }
}
