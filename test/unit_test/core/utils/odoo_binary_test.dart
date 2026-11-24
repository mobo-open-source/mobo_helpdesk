import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_binary.dart';

void main() {
  group('odooBinaryToBase64', () {
    test('Odoo 19 and earlier: a plain base64 string', () {
      expect(odooBinaryToBase64('iVBORw0KGgo='), 'iVBORw0KGgo=');
    });

    test('Odoo 20: the content of the {content, size} dict', () {
      expect(
        odooBinaryToBase64({'content': 'UklGRg==', 'size': 4}),
        'UklGRg==',
      );
      expect(
        odooBinaryToBase64({
          'filename': 'me.png',
          'content': 'iVBORw0KGgo=',
          'size': 8,
        }),
        'iVBORw0KGgo=',
      );
    });

    test('empty on every version: false, null, or anything else', () {
      expect(odooBinaryToBase64(false), '');
      expect(odooBinaryToBase64(null), '');
      expect(odooBinaryToBase64({'size': 0}), '');
      expect(odooBinaryToBase64({'content': 42}), '');
      expect(odooBinaryToBase64(<dynamic>[]), '');
    });
  });
}
