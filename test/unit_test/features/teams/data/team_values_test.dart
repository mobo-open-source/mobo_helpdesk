import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/teams/data/team_values.dart';

void main() {
  // The fields a server has: Odoo 20 (reminder fields, no use_rating) ...
  const odoo20 = {
    'name',
    'description',
    'alias_name',
    'auto_close_day',
    'auto_close_ticket',
    'auto_close_ticket_reminder',
    'auto_close_reminder_delay',
    'reminder_email_template_id',
    'member_ids',
    'from_stage_ids',
    'message_partner_ids',
    'use_sla',
    'use_giftcards',
    'to_stage_id',
    'alias_domain_id',
    'resource_calendar_id',
  };
  // ... and Odoo 17 (use_rating and portal_show_rating, nothing of the above).
  const odoo17 = {
    'name',
    'description',
    'alias_name',
    'auto_close_day',
    'auto_close_ticket',
    'member_ids',
    'from_stage_ids',
    'message_partner_ids',
    'use_sla',
    'use_rating',
    'portal_show_rating',
    'to_stage_id',
  };

  /// What "Create Team" holds with only a name typed.
  Map<String, dynamic> onlyAName() => {
    'name': 'uhh',
    'description': '',
    'alias_name': '',
    'auto_close_day': '',
    'message_partner_ids': <int>[],
    'member_ids': <int>[],
    'from_stage_ids': <int>[],
    'auto_close_ticket': false,
    'auto_close_ticket_reminder': true,
    'auto_close_reminder_delay': '',
    'reminder_email_template_id': null,
    'to_stage_id': null,
    'use_sla': false,
    'use_rating': false,
    'use_giftcards': false,
  };

  group('create', () {
    test('an empty auto-close period is left out, not sent as 0', () {
      // Odoo 20 rejects a team whose reminder delay (2 days) is not shorter
      // than its auto-close period; 0 is what an empty text was read as.
      final values = TeamValues.prepare(onlyAName(), validFields: odoo20);
      expect(values.containsKey('auto_close_day'), isFalse);
      expect(values.containsKey('auto_close_reminder_delay'), isFalse);
    });

    test('keeps the name and settings, drops empty relations', () {
      final values = TeamValues.prepare(onlyAName(), validFields: odoo20);
      expect(values['name'], 'uhh');
      expect(values['use_sla'], false);
      expect(values['auto_close_ticket_reminder'], true);
      expect(values.containsKey('reminder_email_template_id'), isFalse);
      expect(values.containsKey('to_stage_id'), isFalse);
    });

    test('only fields the server has', () {
      final on20 = TeamValues.prepare(onlyAName(), validFields: odoo20);
      expect(on20.containsKey('use_rating'), isFalse);
      expect(on20.containsKey('use_giftcards'), isTrue);

      final on17 = TeamValues.prepare(onlyAName(), validFields: odoo17);
      expect(on17.containsKey('use_rating'), isTrue);
      expect(on17.containsKey('use_giftcards'), isFalse);
      expect(on17.containsKey('auto_close_ticket_reminder'), isFalse);
    });

    test('many2many fields are replace-all commands', () {
      final values = TeamValues.prepare({
        ...onlyAName(),
        'member_ids': [2, 7],
        'message_partner_ids': [5],
      }, validFields: odoo20);
      expect(values['member_ids'], [
        [
          6,
          0,
          [2, 7],
        ],
      ]);
      expect(values['message_partner_ids'], [
        [
          6,
          0,
          [5],
        ],
      ]);
    });

    test('whole numbers of days are sent as numbers', () {
      final values = TeamValues.prepare({
        ...onlyAName(),
        'auto_close_day': ' 10 ',
        'auto_close_reminder_delay': '3',
      }, validFields: odoo20);
      expect(values['auto_close_day'], 10);
      expect(values['auto_close_reminder_delay'], 3);
    });

    test('a period below 1 or unreadable is left out; a delay of 0 is kept', () {
      for (final bad in ['0', '-4', 'abc', '2.5']) {
        expect(
          TeamValues.prepare({
            ...onlyAName(),
            'auto_close_day': bad,
          }, validFields: odoo20).containsKey('auto_close_day'),
          isFalse,
          reason: bad,
        );
      }
      expect(
        TeamValues.prepare({
          ...onlyAName(),
          'auto_close_reminder_delay': '0',
        }, validFields: odoo20)['auto_close_reminder_delay'],
        0,
      );
    });
  });

  group('update', () {
    // The team as the server returns it.
    Map<String, dynamic> stored() => {
      'name': 'Support',
      'description': '<p>Front line</p>',
      'alias_name': false,
      'auto_close_day': 7,
      'auto_close_ticket': true,
      'auto_close_ticket_reminder': true,
      'auto_close_reminder_delay': 2,
      'reminder_email_template_id': [9, 'Reminder'],
      'member_ids': [2, 7],
      'from_stage_ids': [1],
      'message_partner_ids': [5],
      'use_sla': true,
      'use_giftcards': false,
      'to_stage_id': [4, 'Solved'],
      'alias_domain_id': false,
      'resource_calendar_id': [1, '40 hours/week'],
    };

    /// The form as opened, nothing edited.
    Map<String, dynamic> untouched() => {
      'name': 'Support',
      'description': 'Front line',
      'alias_name': '',
      'auto_close_day': '7',
      'auto_close_ticket': true,
      'auto_close_ticket_reminder': true,
      'auto_close_reminder_delay': '2',
      'reminder_email_template_id': 9,
      'member_ids': [7, 2],
      'from_stage_ids': [1],
      'message_partner_ids': [5],
      'use_sla': true,
      'use_giftcards': false,
      'to_stage_id': 4,
      'alias_domain_id': null,
      'resource_calendar_id': 1,
    };

    test('a form nobody touched writes nothing', () {
      expect(
        TeamValues.prepare(
          untouched(),
          validFields: odoo20,
          current: stored(),
        ),
        isEmpty,
      );
    });

    test('only what changed is sent', () {
      final values = TeamValues.prepare(
        {...untouched(), 'name': 'Support EU', 'use_sla': false},
        validFields: odoo20,
        current: stored(),
      );
      expect(values, {'name': 'Support EU', 'use_sla': false});
    });

    test('the last member, partner or stage can be removed', () {
      final values = TeamValues.prepare(
        {
          ...untouched(),
          'member_ids': <int>[],
          'message_partner_ids': <int>[],
          'from_stage_ids': <int>[],
        },
        validFields: odoo20,
        current: stored(),
      );
      expect(values, {
        'member_ids': [
          [6, 0, <int>[]],
        ],
        'message_partner_ids': [
          [6, 0, <int>[]],
        ],
        'from_stage_ids': [
          [6, 0, <int>[]],
        ],
      });
    });

    test('a relation the user emptied is cleared with false', () {
      final values = TeamValues.prepare(
        {...untouched(), 'resource_calendar_id': null},
        validFields: odoo20,
        current: stored(),
      );
      expect(values, {'resource_calendar_id': false});
    });

    test('an empty relation that was already empty is not written', () {
      expect(
        TeamValues.prepare(
          {...untouched(), 'alias_domain_id': null},
          validFields: odoo20,
          current: stored(),
        ),
        isEmpty,
      );
    });

    test('a description with its formatting is kept unless the text changed', () {
      expect(
        TeamValues.prepare(
          {...untouched(), 'description': 'Front line'},
          validFields: odoo20,
          current: stored(),
        ).containsKey('description'),
        isFalse,
      );
      expect(
        TeamValues.prepare(
          {...untouched(), 'description': 'Front line and escalations'},
          validFields: odoo20,
          current: stored(),
        )['description'],
        'Front line and escalations',
      );
    });

    test('changing the period is sent as a number', () {
      final values = TeamValues.prepare(
        {...untouched(), 'auto_close_day': '10'},
        validFields: odoo20,
        current: stored(),
      );
      expect(values, {'auto_close_day': 10});
    });
  });
}
