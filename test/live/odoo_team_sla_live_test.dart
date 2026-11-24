// Runs the team and SLA policy save logic against real Odoo servers.
//
// Skipped unless ODOO_LIVE is set to a comma-separated list of
// `baseUrl|database|login|password`, one per server, for example:
//
//   ODOO_LIVE="http://localhost:8061|db17|user|pw,http://localhost:8064|db20|user|pw" \
//     flutter test test/live/odoo_team_sla_live_test.dart
//
// The login must be a Helpdesk manager. Everything the test creates is deleted
// again. It exercises the real [TeamValues] and [SlaPolicyValues], so what it
// proves about a server is what the app sends to it.
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/sla_policy/data/sla_policy_values.dart';
import 'package:mobo_helpdesk/features/teams/data/team_values.dart';

class _Odoo {
  _Odoo(this.base, this.db, this.login, this.password);

  final String base, db, login, password;
  final HttpClient _http = HttpClient();
  String _cookie = '';
  late final int major;

  Future<dynamic> _post(String path, Map<String, dynamic> params) async {
    final request = await _http.postUrl(Uri.parse('$base$path'));
    request.headers.contentType = ContentType.json;
    if (_cookie.isNotEmpty) request.headers.set('Cookie', _cookie);
    request.write(
      jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params, 'id': 1}),
    );
    final response = await request.close();
    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    if (setCookie != null) {
      for (final c in setCookie) {
        if (c.startsWith('session_id=')) _cookie = c.split(';').first;
      }
    }
    final body = jsonDecode(await response.transform(utf8.decoder).join());
    if (body['error'] != null) {
      final e = body['error'];
      throw StateError(
        '${e['data']?['message'] ?? e['message']}'.split('\n').first,
      );
    }
    return body['result'];
  }

  Future<void> signIn() async {
    final info = await _post('/web/session/authenticate', {
      'db': db,
      'login': login,
      'password': password,
    });
    major = (info['server_version_info'] as List).first as int;
  }

  Future<dynamic> call(
    String model,
    String method, [
    List<dynamic> args = const [],
    Map<String, dynamic> kwargs = const {},
  ]) => _post('/web/dataset/call_kw', {
    'model': model,
    'method': method,
    'args': args,
    'kwargs': kwargs,
  });

  /// `fields_get` for just these names, as the app's resolver asks it.
  Future<Set<String>> fieldsOf(String model, Iterable<String> names) async {
    final result = await call(model, 'fields_get', [
      names.toList(),
      ['type'],
    ]);
    return (result as Map).keys.cast<String>().toSet();
  }
}

void main() {
  final spec = Platform.environment['ODOO_LIVE'];
  if (spec == null || spec.isEmpty) {
    test('live servers', () {}, skip: 'set ODOO_LIVE to run against servers');
    return;
  }

  for (final entry in spec.split(',')) {
    final parts = entry.split('|');
    final odoo = _Odoo(parts[0], parts[1], parts[2], parts[3]);

    group('${parts[0]} (${parts[1]})', () {
      final madeTeams = <int>[];
      final madeSlas = <int>[];
      late int partnerA, partnerB, userA, userB, stageA, stageB;
      late int tagA, tagB;
      var tagMade = false;

      setUpAll(() async {
        await odoo.signIn();
        final partners = await odoo.call('res.partner', 'search_read', [[]], {
          'fields': ['id'],
          'limit': 2,
          'order': 'id',
        });
        partnerA = partners[0]['id'];
        partnerB = partners[1]['id'];
        final users = await odoo.call('res.users', 'search_read', [
          [
            ['share', '=', false],
          ],
        ], {
          'fields': ['id'],
          'limit': 2,
          'order': 'id',
        });
        userA = users[0]['id'];
        userB = users[1]['id'];
        final stages = await odoo.call('helpdesk.stage', 'search_read', [[]], {
          'fields': ['id'],
          'limit': 2,
          'order': 'sequence, id',
        });
        stageA = stages[0]['id'];
        stageB = stages[1]['id'];
        final a = await odoo.call('helpdesk.tag', 'create', [
          {'name': 'live tag A'},
        ]);
        final b = await odoo.call('helpdesk.tag', 'create', [
          {'name': 'live tag B'},
        ]);
        tagA = a is int ? a : (a as List).first;
        tagB = b is int ? b : (b as List).first;
        tagMade = true;
      });

      tearDownAll(() async {
        for (final id in madeSlas) {
          await odoo.call('helpdesk.sla', 'unlink', [
            [id],
          ]).catchError((_) {});
        }
        for (final id in madeTeams) {
          await odoo.call('helpdesk.team', 'unlink', [
            [id],
          ]).catchError((_) {});
        }
        if (tagMade) {
          await odoo.call('helpdesk.tag', 'unlink', [
            [tagA, tagB],
          ]).catchError((_) {});
        }
      });

      // ------------------------------------------------------------- teams
      Future<int> createTeam(Map<String, dynamic> form) async {
        final valid = await odoo.fieldsOf('helpdesk.team', form.keys);
        final values = TeamValues.prepare(form, validFields: valid);
        final id = await odoo.call('helpdesk.team', 'create', [values]);
        final teamId = id is int ? id : (id as List).first as int;
        madeTeams.add(teamId);
        return teamId;
      }

      Future<Map<String, dynamic>> readTeam(int id, Iterable<String> names) async {
        final valid = await odoo.fieldsOf('helpdesk.team', names);
        final rows = await odoo.call('helpdesk.team', 'read', [
          [id],
          valid.toList(),
        ]);
        return Map<String, dynamic>.from(rows.first as Map);
      }

      Future<Map<String, dynamic>> saveTeam(int id, Map<String, dynamic> form) async {
        final valid = await odoo.fieldsOf('helpdesk.team', form.keys);
        final current = await readTeam(id, valid);
        final values = TeamValues.prepare(form, validFields: valid, current: current);
        if (values.isNotEmpty) {
          await odoo.call('helpdesk.team', 'write', [
            [id],
            values,
          ]);
        }
        return values;
      }

      /// What the create form holds with only a name typed.
      Map<String, dynamic> nameOnly(String name) => {
        'name': name,
        'description': '',
        'alias_name': '',
        'auto_close_day': '',
        'message_partner_ids': <int>[],
        'member_ids': <int>[],
        'from_stage_ids': <int>[],
        'auto_assignment': true,
        'use_alias': true,
        'use_sla': false,
        'use_rating': false,
        'portal_show_rating': false,
        'allow_portal_ticket_closing': false,
        'auto_close_ticket': false,
        'auto_close_ticket_reminder': true,
        'auto_close_reminder_delay': '',
        'reminder_email_template_id': null,
        'to_stage_id': null,
        'use_credit_notes': false,
        'use_giftcards': false,
        'use_coupons': false,
        'use_product_returns': false,
        'use_product_replacements': false,
        'use_product_repairs': false,
        'use_fsm': false,
        'alias_domain_id': null,
        'resource_calendar_id': null,
      };

      test('create a team with only a name (the screenshot case)', () async {
        final id = await createTeam(nameOnly('live: only a name'));
        final team = await readTeam(id, ['name', 'auto_close_day', 'auto_close_ticket']);
        expect(team['name'], 'live: only a name');
        // Odoo's own default period, not the 0 an empty text was read as.
        expect(team['auto_close_day'], 7);
        expect(team['auto_close_ticket'], false);
      });

      test('finding the teams of a name, as the app does after a failed save', () async {
        const name = 'live: find me';
        Future<List<int>> idsNamed() async {
          final found = await odoo.call('helpdesk.team', 'search', [
            [
              ['name', '=', name],
            ],
          ], {
            'context': {'active_test': false},
          });
          return List<int>.from(found);
        }

        final before = await idsNamed();
        final id = await createTeam(nameOnly(name));
        final after = await idsNamed();
        expect(after.where((i) => !before.contains(i)), [id]);

        // An archived team still counts: it was created too.
        await odoo.call('helpdesk.team', 'write', [
          [id],
          {'active': false},
        ]);
        expect(await idsNamed(), contains(id));
      });

      test('create with followers, members and stages', () async {
        final id = await createTeam({
          ...nameOnly('live: full'),
          'message_partner_ids': [partnerA, partnerB],
          'member_ids': [userA, userB],
          'use_sla': true,
          'auto_close_ticket': true,
          'auto_close_day': '10',
          'from_stage_ids': [stageA],
        });
        final team = await readTeam(id, [
          'message_partner_ids',
          'member_ids',
          'use_sla',
          'auto_close_ticket',
          'auto_close_day',
          'from_stage_ids',
        ]);
        expect((team['message_partner_ids'] as List).toSet().containsAll({partnerA, partnerB}), isTrue);
        expect(team['member_ids'], containsAll([userA, userB]));
        expect(team['use_sla'], true);
        expect(team['auto_close_ticket'], true);
        expect(team['auto_close_day'], 10);
        expect(team['from_stage_ids'], [stageA]);
      });

      test('a team opened and saved without edits writes nothing', () async {
        final id = await createTeam({
          ...nameOnly('live: untouched'),
          'member_ids': [userA],
          'auto_close_ticket': true,
          'auto_close_day': '9',
        });
        final team = await readTeam(id, [
          'name', 'description', 'alias_name', 'auto_close_day', 'auto_close_ticket',
          'member_ids', 'from_stage_ids', 'use_sla', 'message_partner_ids',
        ]);
        // The form as it opens: what the server returned, shown as text.
        final form = {
          ...nameOnly('live: untouched'),
          'description': '',
          'alias_name': team['alias_name'] is String ? team['alias_name'] : '',
          'auto_close_day': '${team['auto_close_day']}',
          'member_ids': List<int>.from(team['member_ids']),
          'from_stage_ids': List<int>.from(team['from_stage_ids']),
          'message_partner_ids': List<int>.from(team['message_partner_ids']),
          'auto_close_ticket': team['auto_close_ticket'],
          'use_sla': team['use_sla'],
        };
        // Everything that is not in `team` is a default the server also has.
        final sent = await saveTeam(id, {
          for (final k in form.keys)
            if (team.containsKey(k)) k: form[k],
        });
        expect(sent, isEmpty);
      });

      test('edit: rename, and clear members, followers and stages', () async {
        final id = await createTeam({
          ...nameOnly('live: edit me'),
          'member_ids': [userA, userB],
          'message_partner_ids': [partnerA],
          'from_stage_ids': [stageA, stageB],
          'auto_close_ticket': true,
          'auto_close_day': '12',
        });
        await saveTeam(id, {
          'name': 'live: edited',
          'member_ids': <int>[],
          'message_partner_ids': <int>[],
          'from_stage_ids': <int>[],
        });
        final team = await readTeam(id, [
          'name',
          'member_ids',
          'message_partner_ids',
          'from_stage_ids',
          'auto_close_day',
        ]);
        expect(team['name'], 'live: edited');
        expect(team['member_ids'], isEmpty);
        expect(team['from_stage_ids'], isEmpty);
        // followers cannot go below the team's creator on every version, but
        // the one we added is gone
        expect((team['message_partner_ids'] as List).contains(partnerA), isFalse);
        expect(team['auto_close_day'], 12, reason: 'untouched settings stay');
      });

      test('edit: turn automatic closing off again', () async {
        final id = await createTeam({
          ...nameOnly('live: auto close'),
          'auto_close_ticket': true,
          'auto_close_day': '8',
        });
        await saveTeam(id, {'auto_close_ticket': false});
        final team = await readTeam(id, ['auto_close_ticket', 'auto_close_day']);
        expect(team['auto_close_ticket'], false);
        expect(team['auto_close_day'], 8);
      });

      test('edit: an invalid period is not sent', () async {
        final id = await createTeam({
          ...nameOnly('live: bad days'),
          'auto_close_ticket': true,
          'auto_close_day': '8',
        });
        for (final bad in ['', '0', 'abc']) {
          final sent = await saveTeam(id, {'auto_close_day': bad});
          expect(sent.containsKey('auto_close_day'), isFalse, reason: bad);
        }
        expect((await readTeam(id, ['auto_close_day']))['auto_close_day'], 8);
      });

      test('edit: a relation can be cleared', () async {
        final calendars = await odoo.call('resource.calendar', 'search_read', [[]], {
          'fields': ['id'],
          'limit': 1,
        });
        final calendar = calendars.first['id'] as int;
        final id = await createTeam({
          ...nameOnly('live: calendar'),
          'use_sla': true,
          'resource_calendar_id': calendar,
        });
        expect((await readTeam(id, ['resource_calendar_id']))['resource_calendar_id'], isNotEmpty);
        await saveTeam(id, {'use_sla': false, 'resource_calendar_id': null});
        expect((await readTeam(id, ['resource_calendar_id']))['resource_calendar_id'], false);
      });

      test('Odoo 20: the reminder must come before the ticket closes', () async {
        final has = await odoo.fieldsOf('helpdesk.team', ['auto_close_reminder_delay']);
        if (has.isEmpty) return; // earlier versions have no reminder
        final id = await createTeam({
          ...nameOnly('live: reminder'),
          'auto_close_ticket': true,
          'auto_close_day': '10',
          'auto_close_reminder_delay': '3',
        });
        final team = await readTeam(id, ['auto_close_reminder_delay', 'auto_close_ticket_reminder']);
        expect(team['auto_close_reminder_delay'], 3);
        expect(team['auto_close_ticket_reminder'], true);
        // A delay not shorter than the period is refused by Odoo itself when the
        // reminder is saved; the app checks it first, so the user never sees
        // this message from the server.
        await expectLater(
          saveTeam(id, {'auto_close_day': '3', 'auto_close_reminder_delay': '5'}),
          throwsA(predicate((e) => '$e'.contains('must be longer than the reminder'))),
        );
      });

      // --------------------------------------------------------------- SLA
      Future<Set<String>> slaFields(Map<String, dynamic> form, bool domain) =>
          odoo.fieldsOf('helpdesk.sla', {...form.keys, if (domain) 'criteria_domain'});

      Future<bool> usesDomain() async =>
          (await odoo.fieldsOf('helpdesk.sla', ['criteria_domain'])).isNotEmpty;

      Future<int> createSla(Map<String, dynamic> form) async {
        final domain = await usesDomain();
        final values = SlaPolicyValues.prepare(
          form,
          criteriaAsDomain: domain,
          validFields: await slaFields(form, domain),
        );
        final id = await odoo.call('helpdesk.sla', 'create', [values]);
        final slaId = id is int ? id : (id as List).first as int;
        madeSlas.add(slaId);
        return slaId;
      }

      Future<Map<String, dynamic>> readSla(int id, bool domain) async {
        final names = domain
            ? ['name', 'description', 'time', 'team_id', 'stage_id', 'exclude_stage_ids', 'criteria_domain']
            : ['name', 'description', 'time', 'team_id', 'stage_id', 'exclude_stage_ids', 'priority', 'tag_ids', 'partner_ids'];
        final rows = await odoo.call('helpdesk.sla', 'read', [
          [id],
          names,
        ]);
        return Map<String, dynamic>.from(rows.first as Map);
      }

      Future<Map<String, dynamic>> saveSla(int id, Map<String, dynamic> form) async {
        final domain = await usesDomain();
        final valid = await slaFields(form, domain);
        final current = await readSla(id, domain);
        final values = SlaPolicyValues.prepare(
          form,
          criteriaAsDomain: domain,
          validFields: valid,
          current: current,
        );
        if (values.isNotEmpty) {
          await odoo.call('helpdesk.sla', 'write', [
            [id],
            values,
          ]);
        }
        return values;
      }

      late int slaTeam;
      Map<String, dynamic> slaForm(String name) => {
        'name': name,
        'description': 'Reply quickly',
        'time': '8',
        'priority': '2',
        'team_id': slaTeam,
        'stage_id': stageB,
        'tag_ids': [tagA],
        'partner_ids': [partnerA],
        'exclude_stage_ids': [stageA],
      };

      test('SLA: create with criteria', () async {
        slaTeam = await createTeam({...nameOnly('live: sla team'), 'use_sla': true});
        final id = await createSla(slaForm('live sla'));
        final domain = await usesDomain();
        final sla = await readSla(id, domain);
        expect(sla['time'], 8.0);
        expect(sla['exclude_stage_ids'], [stageA]);
        if (domain) {
          final text = sla['criteria_domain'] as String;
          expect(text, contains('priority'));
          expect(text, contains('$tagA'));
        } else {
          expect(sla['priority'], '2');
          expect(sla['tag_ids'], [tagA]);
          expect(sla['partner_ids'], [partnerA]);
        }
      });

      test('SLA: a form nobody touched writes nothing', () async {
        slaTeam = await createTeam({...nameOnly('live: sla team 2'), 'use_sla': true});
        final id = await createSla(slaForm('live sla untouched'));
        final sent = await saveSla(id, slaForm('live sla untouched'));
        expect(sent, isEmpty);
      });

      test('SLA: edit and remove tags, customers and excluded stages', () async {
        slaTeam = await createTeam({...nameOnly('live: sla team 3'), 'use_sla': true});
        final id = await createSla({
          ...slaForm('live sla edit'),
          'tag_ids': [tagA, tagB],
          'exclude_stage_ids': [stageA],
        });
        await saveSla(id, {
          ...slaForm('live sla edit'),
          'time': '4,5',
          'priority': '0',
          'tag_ids': <int>[],
          'partner_ids': <int>[],
          'exclude_stage_ids': <int>[],
        });
        final domain = await usesDomain();
        final sla = await readSla(id, domain);
        expect(sla['time'], 4.5);
        expect(sla['exclude_stage_ids'], isEmpty);
        if (domain) {
          expect(sla['criteria_domain'], anyOf(false, '[]'));
        } else {
          expect(sla['priority'], '0');
          expect(sla['tag_ids'], isEmpty);
          expect(sla['partner_ids'], isEmpty);
        }
      });

      test('SLA (Odoo 20): clauses set in the web client survive an edit', () async {
        if (!await usesDomain()) return;
        slaTeam = await createTeam({...nameOnly('live: sla team 4'), 'use_sla': true});
        final id = await createSla(slaForm('live sla foreign'));
        // someone adds a condition in Odoo's own domain editor
        await odoo.call('helpdesk.sla', 'write', [
          [id],
          {
            'criteria_domain':
                "[('priority', '>=', '2'), ('tag_ids', 'in', [$tagA]), ('name', 'ilike', 'vip')]",
          },
        ]);
        await saveSla(id, {...slaForm('live sla foreign'), 'priority': '3', 'tag_ids': <int>[]});
        final text = (await readSla(id, true))['criteria_domain'] as String;
        expect(text, contains("'name'"), reason: text);
        expect(text, contains("'3'"), reason: text);
        expect(text, isNot(contains("'tag_ids'")), reason: text);
      });
    });
  }
}
