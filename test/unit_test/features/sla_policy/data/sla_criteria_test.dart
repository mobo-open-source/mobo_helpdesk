import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/sla_policy/data/sla_criteria.dart';

void main() {
  group('SlaCriteria.expand', () {
    test('turns the stored domain into the fields the screens use', () {
      final record = <String, dynamic>{
        'criteria_domain':
            "[('priority', '>=', '2'), ('tag_ids', 'in', [4, 5]), "
            "('partner_id', 'in', [9])]",
      };
      SlaCriteria.expand(record);
      expect(record['priority'], '2');
      expect(record['tag_ids'], [4, 5]);
      expect(record['partner_ids'], [9]);
    });

    test('a policy with no criteria shows none', () {
      final record = <String, dynamic>{'criteria_domain': false};
      SlaCriteria.expand(record);
      expect(record['priority'], '0');
      expect(record['tag_ids'], isEmpty);
      expect(record['partner_ids'], isEmpty);
    });

    test('criteria the screens cannot show are left out, not misread', () {
      final record = <String, dynamic>{
        'criteria_domain': "[('priority', '=', '3')]",
      };
      SlaCriteria.expand(record);
      expect(record['priority'], '0');
    });

    test('an unreadable domain shows no criteria', () {
      final record = <String, dynamic>{'criteria_domain': "[('a', '=', uid)]"};
      SlaCriteria.expand(record);
      expect(record['priority'], '0');
      expect(record['tag_ids'], isEmpty);
    });
  });

  group('SlaCriteria.toServer', () {
    test('writes the screen fields as one criteria domain', () {
      final values = SlaCriteria.toServer({
        'name': 'Fast',
        'priority': '2',
        'tag_ids': [4],
        'partner_ids': [9, 10],
        'ticket_type_ids': [1],
      });
      expect(values, {
        'name': 'Fast',
        'criteria_domain':
            "[('priority', '>=', '2'), ('tag_ids', 'in', [4]), "
            "('partner_id', 'in', [9, 10])]",
      });
    });

    test('accepts priority as a number', () {
      final values = SlaCriteria.toServer({'priority': 3});
      expect(values['criteria_domain'], "[('priority', '>=', '3')]");
    });

    test('no criteria at all clears the domain', () {
      final values = SlaCriteria.toServer({
        'name': 'Any',
        'priority': '0',
        'tag_ids': <int>[],
        'partner_ids': <int>[],
      });
      expect(values['criteria_domain'], false);
      expect(values.containsKey('priority'), isFalse);
    });

    test('a write without criteria leaves them alone', () {
      final data = {'name': 'Renamed', 'active': false};
      expect(SlaCriteria.toServer(data), data);
    });

    test('keeps clauses the screens do not own', () {
      final values = SlaCriteria.toServer(
        {
          'priority': '1',
          'tag_ids': <int>[],
          'partner_ids': [7],
        },
        currentDomain:
            "[('priority', '>=', '3'), ('team_id.name', 'ilike', 'x'), "
            "'|', ('active', '=', True), ('user_id', '=', False)]",
      );
      expect(
        values['criteria_domain'],
        "[('team_id.name', 'ilike', 'x'), "
        "'|', ('active', '=', True), ('user_id', '=', False), "
        "('priority', '>=', '1'), ('partner_id', 'in', [7])]",
      );
    });

    test('removing every criterion keeps the foreign ones', () {
      final values = SlaCriteria.toServer(
        {'priority': '0', 'tag_ids': <int>[], 'partner_ids': <int>[]},
        currentDomain:
            "[('priority', '>=', '3'), ('company_id', '=', 1)]",
      );
      expect(values['criteria_domain'], "[('company_id', '=', 1)]");
    });

    test('refuses to overwrite a domain it cannot read', () {
      expect(
        () => SlaCriteria.toServer({
          'priority': '2',
          'tag_ids': <int>[],
          'partner_ids': <int>[],
        }, currentDomain: "[('a', '=', uid)]"),
        throwsA(isA<SlaCriteriaException>()),
      );
    });

    test('saves other changes to a policy whose domain it cannot read', () {
      final values = SlaCriteria.toServer({
        'name': 'Renamed',
        'priority': '0',
        'tag_ids': <int>[],
        'partner_ids': <int>[],
      }, currentDomain: "[('a', '=', uid)]");
      expect(values, {'name': 'Renamed'});
    });
  });
}
