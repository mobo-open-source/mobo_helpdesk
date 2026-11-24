import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_domain.dart';

void main() {
  group('OdooDomain.tryParse', () {
    test('reads the text Odoo itself stores', () {
      expect(
        OdooDomain.tryParse(
          "[('partner_id', 'in', [12, 4]), ('priority', '=', '3')]",
        ),
        [
          ['partner_id', 'in', [12, 4]],
          ['priority', '=', '3'],
        ],
      );
    });

    test('reads the text the web client writes', () {
      expect(
        OdooDomain.tryParse(
          '[("active", "=", True), ("user_id", "=", False), ("x", "!=", None)]',
        ),
        [
          ['active', '=', true],
          ['user_id', '=', false],
          ['x', '!=', null],
        ],
      );
    });

    test('reads operators, negative and decimal numbers, escapes', () {
      expect(
        OdooDomain.tryParse(r"['|', ('a', '>', -1.5), ('b', '=', 'it\'s')]"),
        [
          '|',
          ['a', '>', -1.5],
          ['b', '=', "it's"],
        ],
      );
    });

    test('empty text is the empty domain', () {
      expect(OdooDomain.tryParse(null), isEmpty);
      expect(OdooDomain.tryParse('  '), isEmpty);
      expect(OdooDomain.tryParse('[]'), isEmpty);
    });

    test('gives up on anything that is not a literal list', () {
      expect(OdooDomain.tryParse("[('a', '=', uid)]"), isNull);
      expect(OdooDomain.tryParse("[('a', '=', 1)"), isNull);
      expect(OdooDomain.tryParse("[('a', '=', 'x')] extra"), isNull);
      expect(OdooDomain.tryParse("'just a string'"), isNull);
    });
  });

  group('OdooDomain.format', () {
    test('writes leaves as tuples and values as Python literals', () {
      expect(
        OdooDomain.format([
          ['priority', '>=', '2'],
          ['tag_ids', 'in', [1, 2]],
          ['active', '=', true],
        ]),
        "[('priority', '>=', '2'), ('tag_ids', 'in', [1, 2]), ('active', '=', True)]",
      );
    });

    test('quotes and escapes strings', () {
      expect(
        OdooDomain.format([
          ['name', '=', "O'Brien \\ co"],
        ]),
        r"[('name', '=', 'O\'Brien \\ co')]",
      );
    });

    test('keeps operators as plain strings', () {
      expect(
        OdooDomain.format([
          '|',
          ['a', '=', 1],
          ['b', '=', 2],
        ]),
        "['|', ('a', '=', 1), ('b', '=', 2)]",
      );
    });

    test('what it writes it can read back', () {
      final domain = [
        '|',
        ['a', '=', "it's"],
        ['b', 'in', [1, 2, 3]],
        ['c', '=', null],
        ['d', '=', false],
      ];
      expect(OdooDomain.tryParse(OdooDomain.format(domain)), domain);
    });
  });

  group('OdooDomain.splitTopLevel', () {
    test('separates the expressions that are ANDed', () {
      final a = ['a', '=', 1];
      final b = ['b', '=', 2];
      final c = ['c', '=', 3];
      final d = ['d', '=', 4];
      expect(OdooDomain.splitTopLevel(['|', a, b, c, '!', d]), [
        ['|', a, b],
        [c],
        ['!', d],
      ]);
    });

    test('nested operators stay in one expression', () {
      final a = ['a', '=', 1];
      final b = ['b', '=', 2];
      final c = ['c', '=', 3];
      expect(OdooDomain.splitTopLevel(['&', '|', a, b, c]), [
        ['&', '|', a, b, c],
      ]);
    });

    test('is null when the prefix notation is cut short', () {
      expect(OdooDomain.splitTopLevel(['|', ['a', '=', 1]]), isNull);
      expect(OdooDomain.splitTopLevel(['!']), isNull);
    });

    test('empty domain has no expressions', () {
      expect(OdooDomain.splitTopLevel([]), isEmpty);
    });
  });
}
