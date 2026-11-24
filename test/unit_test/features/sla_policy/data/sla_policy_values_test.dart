import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/sla_policy/data/sla_policy_values.dart';

void main() {
  // Up to Odoo 19: priority, tags and customers are fields of their own.
  const legacy = {
    'name',
    'description',
    'team_id',
    'stage_id',
    'time',
    'priority',
    'tag_ids',
    'partner_ids',
    'exclude_stage_ids',
  };
  // Odoo 20: one criteria domain instead.
  const odoo20 = {
    'name',
    'description',
    'team_id',
    'stage_id',
    'time',
    'criteria_domain',
    'exclude_stage_ids',
  };

  Map<String, dynamic> form() => {
    'name': 'Fast',
    'description': 'Reply quickly',
    'time': '8',
    'priority': '2',
    'team_id': 1,
    'stage_id': 3,
    'tag_ids': [4],
    'partner_ids': <int>[],
    'exclude_stage_ids': [5, 6],
  };

  group('legacy servers (Odoo 17-19)', () {
    test('create: many2many as commands, time as a number', () {
      final values = SlaPolicyValues.prepare(
        form(),
        criteriaAsDomain: false,
        validFields: legacy,
      );
      expect(values['time'], 8.0);
      expect(values['priority'], '2');
      expect(values['tag_ids'], [
        [
          6,
          0,
          [4],
        ],
      ]);
      expect(values['partner_ids'], [
        [6, 0, <int>[]],
      ]);
      expect(values['exclude_stage_ids'], [
        [
          6,
          0,
          [5, 6],
        ],
      ]);
      expect(values.containsKey('criteria_domain'), isFalse);
    });

    test('time: a comma is accepted, empty or unreadable is left out', () {
      double? timeOf(String text) =>
          SlaPolicyValues.prepare(
                {...form(), 'time': text},
                criteriaAsDomain: false,
                validFields: legacy,
              )['time']
              as double?;
      expect(timeOf('1,5'), 1.5);
      expect(timeOf(' 12 '), 12.0);
      expect(timeOf(''), isNull);
      expect(timeOf('soon'), isNull);
      expect(timeOf('-3'), isNull);
    });

    test('update: a form nobody touched writes nothing', () {
      final current = {
        'name': 'Fast',
        'description': '<p>Reply quickly</p>',
        'time': 8.0,
        'priority': '2',
        'team_id': [1, 'Support'],
        'stage_id': [3, 'Solved'],
        'tag_ids': [4],
        'partner_ids': <int>[],
        'exclude_stage_ids': [6, 5],
      };
      expect(
        SlaPolicyValues.prepare(
          form(),
          criteriaAsDomain: false,
          validFields: legacy,
          current: current,
        ),
        isEmpty,
      );
    });

    test('update: the last tag can be removed', () {
      final values = SlaPolicyValues.prepare(
        {...form(), 'tag_ids': <int>[]},
        criteriaAsDomain: false,
        validFields: legacy,
        current: {
          'name': 'Fast',
          'description': 'Reply quickly',
          'time': 8.0,
          'priority': '2',
          'team_id': [1, 'x'],
          'stage_id': [3, 'x'],
          'tag_ids': [4],
          'partner_ids': <int>[],
          'exclude_stage_ids': [5, 6],
        },
      );
      expect(values, {
        'tag_ids': [
          [6, 0, <int>[]],
        ],
      });
    });
  });

  group('Odoo 20', () {
    test('create: criteria become one domain, legacy fields are gone', () {
      final values = SlaPolicyValues.prepare(
        form(),
        criteriaAsDomain: true,
        validFields: odoo20,
      );
      expect(
        values['criteria_domain'],
        "[('priority', '>=', '2'), ('tag_ids', 'in', [4])]",
      );
      for (final gone in ['priority', 'tag_ids', 'partner_ids']) {
        expect(values.containsKey(gone), isFalse, reason: gone);
      }
      expect(values['exclude_stage_ids'], [
        [
          6,
          0,
          [5, 6],
        ],
      ]);
    });

    test('update keeps the clauses the form does not own', () {
      final values = SlaPolicyValues.prepare(
        {...form(), 'priority': '0', 'tag_ids': <int>[]},
        criteriaAsDomain: true,
        validFields: odoo20,
        current: {
          'name': 'Fast',
          'description': 'Reply quickly',
          'time': 8.0,
          'team_id': [1, 'x'],
          'stage_id': [3, 'x'],
          'exclude_stage_ids': [5, 6],
          'criteria_domain':
              "[('priority', '>=', '2'), ('tag_ids', 'in', [4]), "
              "('company_id', '=', 1)]",
        },
      );
      expect(values, {'criteria_domain': "[('company_id', '=', 1)]"});
    });

    test('update: unchanged criteria write nothing', () {
      expect(
        SlaPolicyValues.prepare(
          form(),
          criteriaAsDomain: true,
          validFields: odoo20,
          current: {
            'name': 'Fast',
            'description': 'Reply quickly',
            'time': 8.0,
            'team_id': [1, 'x'],
            'stage_id': [3, 'x'],
            'exclude_stage_ids': [5, 6],
            'criteria_domain':
                "[('priority', '>=', '2'), ('tag_ids', 'in', [4])]",
          },
        ),
        isEmpty,
      );
    });
  });
}
