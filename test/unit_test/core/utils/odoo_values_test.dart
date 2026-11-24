import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_values.dart';

void main() {
  group('replaceWith', () {
    test('is the replace-all command, empty list included', () {
      expect(OdooValues.replaceWith([1, 2]), [
        [
          6,
          0,
          [1, 2],
        ],
      ]);
      expect(OdooValues.replaceWith(<int>[]), [
        [6, 0, <int>[]],
      ]);
    });

    test('ignores anything that is not an id', () {
      expect(OdooValues.replaceWith([1, 'x', null, 3]), [
        [
          6,
          0,
          [1, 3],
        ],
      ]);
    });
  });

  group('relationId / relationIds', () {
    test('a many2one in any of its shapes', () {
      expect(OdooValues.relationId([4, 'Sales']), 4);
      expect(OdooValues.relationId({'id': 4, 'display_name': 'Sales'}), 4);
      expect(OdooValues.relationId(4), 4);
      expect(OdooValues.relationId(false), isNull);
      expect(OdooValues.relationId(null), isNull);
    });

    test('a many2many from a read or from a replace-all command', () {
      expect(OdooValues.relationIds([3, 5]), {3, 5});
      expect(OdooValues.relationIds(OdooValues.replaceWith([3, 5])), {3, 5});
      expect(OdooValues.relationIds(false), isEmpty);
    });
  });

  group('unchanged', () {
    test('lists compare as sets, whatever the order or form', () {
      expect(OdooValues.unchanged(OdooValues.replaceWith([2, 1]), [1, 2]), isTrue);
      expect(OdooValues.unchanged(OdooValues.replaceWith([1]), [1, 2]), isFalse);
      expect(OdooValues.unchanged(OdooValues.replaceWith([]), []), isTrue);
    });

    test('a many2one id against [id, name] or false', () {
      expect(OdooValues.unchanged(7, [7, 'x']), isTrue);
      expect(OdooValues.unchanged(8, [7, 'x']), isFalse);
      expect(OdooValues.unchanged(7, false), isFalse);
    });

    test('empty text equals false, html equals its text', () {
      expect(OdooValues.unchanged('', false), isTrue);
      expect(OdooValues.unchanged('Hi', 'Hi'), isTrue);
      expect(OdooValues.unchanged('Hi', '<p>Hi</p>', html: true), isTrue);
      expect(OdooValues.unchanged('Hello', '<p>Hi</p>', html: true), isFalse);
    });

    test('booleans and numbers', () {
      expect(OdooValues.unchanged(false, false), isTrue);
      expect(OdooValues.unchanged(true, false), isFalse);
      expect(OdooValues.unchanged(false, null), isTrue);
      expect(OdooValues.unchanged(false, [7, 'x']), isFalse); // clears it
      expect(OdooValues.unchanged(false, "[('a', '=', 1)]"), isFalse); // clears
      expect(OdooValues.unchanged(false, ''), isTrue);
      expect(OdooValues.unchanged(true, "[('a', '=', 1)]"), isFalse);
      expect(OdooValues.unchanged(false, false), isTrue);
      expect(OdooValues.unchanged(7, 7), isTrue);
      expect(OdooValues.unchanged(7.0, 7), isTrue);
      expect(OdooValues.unchanged(8, 7), isFalse);
    });
  });
}
