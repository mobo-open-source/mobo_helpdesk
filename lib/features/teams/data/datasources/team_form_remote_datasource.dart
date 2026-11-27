import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../../core/session/company_session_manager.dart';
import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/odoo_install_errors.dart';
import '../../../../core/utils/odoo_record_counts.dart';
import '../team_values.dart';
import '../../../../core/widgets/api_validation_error.dart';

/// Contract for remote operations related to Helpdesk Team form.
///
/// Defines all required API operations such as:
/// - Loading team details
/// - Fetching related entities (members, partners, stages, etc.)
/// - Creating and updating team records
abstract class TeamFormRemoteDatasource {
  Future<List<Map<String, dynamic>>> loadTeamData(int id);

  Future<List<Map<String, dynamic>>> loadMembers();

  Future<List<Map<String, dynamic>>> loadPartners();

  Future<List<Map<String, dynamic>>> loadWebsite();

  Future<List<Map<String, dynamic>>> loadResourceCalendar(int? companyId);

  Future<List<Map<String, dynamic>>> loadStages();

  Future<List<Map<String, dynamic>>> loadProjects();

  Future<List<Map<String, dynamic>>> loadAliasDomain();

  Future<void> loadProjectModules(int id);

  Future<void> loadWebsiteModules(int id);

  /// Email templates a team can use for the auto-close reminder (Odoo 20).
  Future<List<Map<String, dynamic>>> loadReminderTemplates();

  /// What Odoo fills in for a new team: the auto-close period and the reminder
  /// fields. Empty where the server says nothing.
  Future<Map<String, dynamic>> loadTeamDefaults();

  /// Which of [optionFields] (team options that are switched on, such as
  /// `use_helpdesk_timesheet`) would make saving install an Odoo app on the
  /// server. Empty when none would, or when the server cannot say.
  Future<List<String>> optionsNeedingInstall(List<String> optionFields);

  /// Whether the server is in the middle of installing, upgrading or removing
  /// apps. Saving a team that needs an app is refused until it is done.
  Future<bool> isServerBusyInstalling();

  /// Whether the server already holds everything in [data] for team [id]: the
  /// values are the stored ones, so writing them would change nothing.
  Future<bool> holdsSave(int id, Map<String, dynamic> data);

  /// The ids of the teams called [name], archived ones included. Compared
  /// before and after a save to tell whether the server created the team even
  /// though the answer never arrived.
  Future<List<int>> teamIdsNamed(String name);

  Future<void> createTeam(Map<String, dynamic> data);

  /// [installs]: the save is meant to install apps, so it must reach Odoo even
  /// when nothing in the form differs from what is stored (Odoo installs the
  /// apps of the switched-on options whenever a team is written).
  Future<void> updateTeam(
    int id,
    Map<String, dynamic> data, {
    bool installs = false,
  });
}

/// Implementation of [TeamFormRemoteDatasource].
///
/// Uses Odoo RPC calls through [CompanySessionManager] to interact
/// with backend models like `helpdesk.team`, `res.users`,
/// `res.partner`, and related modules.
class TeamFormRemoteDatasourceImpl implements TeamFormRemoteDatasource {
  /// Fetches display names for a list of record IDs from a given model.
  ///
  /// Used to resolve Many2many relational fields into readable data.
  ///
  /// Returns a list of maps containing:
  /// - `id`: record ID
  /// - `name`: display name
  ///
  /// Returns an empty list if [ids] is empty.
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

  /// Loads detailed information for a specific Helpdesk Team.
  ///
  /// This includes:
  /// - Core team fields (name, description, settings)
  /// - Conditional module fields (website/project if installed)
  /// - Related data such as members, followers, and stages
  ///
  /// The method also enriches response with:
  /// - `members`: resolved user list
  /// - `messagePartners`: follower list
  /// - `stages`: available stage list for team transitions
  ///
  /// Throws formatted error maps on failure.
  @override
  Future<List<Map<String, dynamic>>> loadTeamData(int teamId) async {
    try {
      List<String> fields = [
        'id',
        'name',
        'description',
        'privacy_visibility',
        // The followers the team form shows: partners, not `mail.followers` rows.
        'message_partner_ids',
        'auto_assignment',
        'member_ids',
        'assign_method',
        'use_alias',
        'alias_name',
        'alias_domain_id',
        'alias_contact',
        'use_website_helpdesk_livechat',
        'use_website_helpdesk_form',
        'use_website_helpdesk_forum',
        'use_website_helpdesk_knowledge',
        'use_website_helpdesk_slides',
        'use_helpdesk_timesheet',
        'use_helpdesk_sale_timesheet',
        'use_sla',
        'resource_calendar_id',
        'allow_portal_ticket_closing',
        'auto_close_ticket',
        'auto_close_day',
        'to_stage_id',
        'from_stage_ids',
        'use_credit_notes',
        'use_giftcards',
        'use_coupons',
        'use_product_returns',
        'use_product_replacements',
        'use_product_repairs',
        'use_fsm',
        // Up to Odoo 19 ratings are a team setting (and Odoo 17 can also show
        // them on the portal); Odoo 20 moved them to the stages.
        'use_rating',
        'portal_show_rating',
        // Odoo 20: remind the customer before an inactive ticket is closed.
        'auto_close_ticket_reminder',
        'auto_close_reminder_delay',
        'reminder_email_template_id',
        // Present only when the website / timesheet apps are installed.
        'website_id',
        'project_id',
        'open_ticket_count',
        'sla_policy_count',
        'active',
        'company_id',
      ];

      // Which of these the server has varies with its version and with the apps
      // installed: ask it, rather than naming a field it would reject and
      // failing the whole form.
      // If the server cannot be asked, only the fields every version has.
      const versionSpecific = {
        'use_giftcards',
        'use_product_replacements',
        'use_rating',
        'portal_show_rating',
        'auto_close_ticket_reminder',
        'auto_close_reminder_delay',
        'reminder_email_template_id',
        'website_id',
        'project_id',
      };
      fields = await OdooFieldResolver.availableFields(
        'helpdesk.team',
        fields,
        whenUnknown: [
          for (final field in fields)
            if (!versionSpecific.contains(field)) field,
        ],
      );

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', teamId],
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
        // The screens read it as a plain switch; where the server has none,
        // it is off.
        json['use_rating'] ??= false;
        // Read with `active_test: false` so an archived team opens, these two
        // counts would include archived tickets and policies; Odoo's form
        // counts only the active ones.
        json.addAll(
          await OdooRecordCounts.read('helpdesk.team', teamId, [
            for (final count in const ['open_ticket_count', 'sla_policy_count'])
              if (fields.contains(count)) count,
          ]),
        );
        final messagePartners = await fetchNames(
          'res.partner',
          json['message_partner_ids'] ?? [],
        );
        final members = await fetchNames('res.users', json['member_ids'] ?? []);
        final stages = await fetchNames(
          'helpdesk.stage',
          json['from_stage_ids'] ?? [],
        );

        json['members'] = members;
        json['messagePartners'] = messagePartners;
        json['stages'] = stages;
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
        'description': 'Error fetching team, Please try again later.',
      };
    }
  }

  /// Fetches all system users available as team members.
  ///
  /// Returns a list of users containing:
  /// - id
  /// - name
  @override
  Future<List<Map<String, dynamic>>> loadMembers() async {
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

  /// Fetches all partners (customers/vendors) available in the system.
  ///
  /// Returns a list containing:
  /// - id
  /// - name
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

  /// Fetches available websites from the system.
  ///
  /// Used when configuring Helpdesk website-related features.
  @override
  Future<List<Map<String, dynamic>>> loadWebsite() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'website',
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

  /// Fetches available working calendars.
  ///
  /// Used to define team working schedules and SLA timing rules.
  @override
  Future<List<Map<String, dynamic>>> loadResourceCalendar(
    int? companyId,
  ) async {
    try {
      // Odoo 18 and 19 flag calendars without fixed hours with
      // `flexible_hours`; Odoo 20 replaced the flag and no longer asks.
      final hasFlexibleFlag = await OdooFieldResolver.hasField(
        'resource.calendar',
        'flexible_hours',
      );
      final domain = [
        '&',
        if (hasFlexibleFlag) '&',
        '|',
        ['company_id', '=', false],
        ['company_id', '=', companyId],
        if (hasFlexibleFlag) ['flexible_hours', '=', false],
        ['attendance_ids', '!=', false],
      ];

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'resource.calendar',
        'method': 'search_read',
        'args': [domain],
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

  /// Fetches Helpdesk stages used for team workflow configuration.
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

  /// Fetches available projects from the system.
  ///
  /// Used when linking Helpdesk teams with project management features.
  @override
  Future<List<Map<String, dynamic>>> loadProjects() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'project.project',
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

  /// Fetches available mail alias domains.
  ///
  /// Used for configuring email-based ticket creation.
  @override
  Future<List<Map<String, dynamic>>> loadAliasDomain() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mail.alias.domain',
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

  /// Enables specific Helpdesk team features by updating backend flags.
  ///
  /// - [loadProjectModules] enables timesheet/project integration
  ///
  /// These methods update `helpdesk.team` configuration.
  @override
  Future<void> loadProjectModules(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'write',
        'args': [
          [id],
          {'use_helpdesk_timesheet': true},
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
      throw 'Error creating ticket';
    }
  }

  /// Enables specific Helpdesk team features by updating backend flags.
  ///
  /// - [loadWebsiteModules] enables website form support
  ///
  /// These methods update `helpdesk.team` configuration.
  @override
  Future<void> loadWebsiteModules(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'write',
        'args': [
          [id],
          {'use_website_helpdesk_form': true},
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
      throw 'Error creating ticket';
    }
  }

  @override
  Future<List<String>> optionsNeedingInstall(List<String> optionFields) async {
    if (optionFields.isEmpty) return [];
    Future<bool> needsInstall(List<String> fields) async =>
        await CompanySessionManager.callKwWithCompany({
          'model': 'helpdesk.team',
          // The question Odoo's own team form asks before it saves.
          'method': 'check_modules_to_install',
          'args': [fields],
          'kwargs': {},
        }) ==
        true;

    try {
      if (!await needsInstall(optionFields)) return [];
      // Which ones: one question each, so the user can be told by name.
      final answers = await Future.wait([
        for (final field in optionFields) needsInstall([field]),
      ]);
      final needing = [
        for (var i = 0; i < optionFields.length; i++)
          if (answers[i]) optionFields[i],
      ];
      return needing.isEmpty ? optionFields : needing;
    } catch (_) {
      return []; // not knowing is not a reason to stop the save
    }
  }

  @override
  Future<bool> isServerBusyInstalling() async {
    try {
      final busy = await CompanySessionManager.callKwWithCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            [
              'state',
              'in',
              ['to install', 'to upgrade', 'to remove'],
            ],
          ],
        ],
        'kwargs': {},
      });
      return busy is int && busy > 0;
    } on OdooException {
      return false; // refused, not busy: waiting would not help
    } catch (_) {
      // No answer at all: the server is most likely reloading.
      return true;
    }
  }

  /// The fields of [data] that `helpdesk.team` has on this server.
  Future<Set<String>> _teamFieldsIn(Map<String, dynamic> data) async =>
      (await OdooFieldResolver.availableFields(
        'helpdesk.team',
        data.keys.toList(),
      )).toSet();

  @override
  Future<List<Map<String, dynamic>>> loadReminderTemplates() async {
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
    return response is List ? List<Map<String, dynamic>>.from(response) : [];
  }

  @override
  Future<Map<String, dynamic>> loadTeamDefaults() async {
    try {
      final wanted = await OdooFieldResolver.availableFields('helpdesk.team', [
        'auto_close_day',
        'auto_close_ticket_reminder',
        'auto_close_reminder_delay',
      ]);
      if (wanted.isEmpty) return {};
      final defaults = await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'default_get',
        'args': [wanted],
        'kwargs': {},
      });
      return defaults is Map ? Map<String, dynamic>.from(defaults) : {};
    } catch (_) {
      return {};
    }
  }

  /// Creates a new Helpdesk Team in the backend.
  ///
  /// Accepts a map of team configuration data and sends it to Odoo.
  /// Throws formatted error messages if creation fails.
  @override
  Future<void> createTeam(Map<String, dynamic> data) async {
    try {
      final values = TeamValues.prepare(
        data,
        validFields: await _teamFieldsIn(data),
      );

      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
        'method': 'create',
        'args': [values],
        'kwargs': {},
      });
    } on OdooException catch (e) {
      final error = extractOdooError(e);
      final errorMsg =
          error['description'] ??
          'Something went wrong. Please try again later.';
      throw OdooInstallErrors.reword(errorMsg.toString());
    } catch (e) {
      throw _connectionLost('create');
    }
  }

  @override
  Future<List<int>> teamIdsNamed(String name) async {
    final found = await CompanySessionManager.callKwWithCompany({
      'model': 'helpdesk.team',
      'method': 'search',
      'args': [
        [
          ['name', '=', name],
        ],
      ],
      'kwargs': {
        'context': {'active_test': false},
      },
    });
    return found is List ? List<int>.from(found) : <int>[];
  }

  /// Said when the connection drops during a save. A save can be installing
  /// apps, which the server finishes even if the app stopped listening.
  OdooConnectionLost _connectionLost(String verb) => OdooConnectionLost(
    'Could not $verb the team: the connection to the server was lost. If '
    'apps were being installed, the server may still be working - wait a few '
    'minutes and check the team list before trying again.',
  );

  /// What team [id] holds for [fields], archived included.
  Future<Map<String, dynamic>> _storedTeam(int id, Set<String> fields) async {
    final stored = await CompanySessionManager.callKwWithCompany({
      'model': 'helpdesk.team',
      'method': 'read',
      'args': [
        [id],
        fields.toList(),
      ],
      'kwargs': {
        'context': {'active_test': false},
      },
    });
    return stored is List && stored.isNotEmpty
        ? Map<String, dynamic>.from(stored.first as Map)
        : <String, dynamic>{};
  }

  @override
  Future<bool> holdsSave(int id, Map<String, dynamic> data) async {
    final validFields = await _teamFieldsIn(data);
    final current = await _storedTeam(id, validFields);
    return TeamValues.prepare(
      data,
      validFields: validFields,
      current: current,
    ).isEmpty;
  }

  /// Updates an existing Helpdesk Team.
  ///
  /// Requires:
  /// - [id]: team identifier
  /// - [data]: updated fields map
  ///
  /// Throws formatted error messages on failure.
  @override
  Future<void> updateTeam(
    int id,
    Map<String, dynamic> data, {
    bool installs = false,
  }) async {
    try {
      final validFields = await _teamFieldsIn(data);

      // What the team holds now, so only what was edited is written: saving a
      // team must not rewrite the settings the user did not touch.
      final current = await _storedTeam(id, validFields);

      var values = TeamValues.prepare(
        data,
        validFields: validFields,
        current: current,
      );
      if (values.isEmpty) {
        if (!installs) return; // nothing was edited
        // The options are on but their apps are not installed (an earlier
        // install failed). Odoo installs them whenever the team is written, so
        // write the options as they are rather than skip the save.
        values = {
          for (final entry in data.entries)
            if (entry.key.startsWith('use_') &&
                entry.value == true &&
                validFields.contains(entry.key))
              entry.key: true,
        };
        if (values.isEmpty) return;
      }

      await CompanySessionManager.callKwWithCompany({
        'model': 'helpdesk.team',
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
      throw OdooInstallErrors.reword(errorMsg.toString());
    } catch (e) {
      throw _connectionLost('save');
    }
  }
}
