import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_install_errors.dart';

void main() {
  group('OdooInstallErrors', () {
    test('a registry that is not ready (the log message from Odoo)', () {
      final text = OdooInstallErrors.friendly(
        'The method _button_immediate_install cannot be called on init or non '
        'loaded registries. Please use button_install instead.',
      );
      expect(text, contains('still starting up or reloading'));
      expect(text, isNot(contains('_button_immediate_install')));
    });

    test('another installation already running (Odoo 19 and 20)', () {
      expect(
        OdooInstallErrors.friendly(
          'Odoo is currently processing another module operation.\n'
          'Please try again later or contact your system administrator.',
        ),
        contains('Another installation is already running'),
      );
    });

    test('a scheduled action in the way (every version)', () {
      expect(
        OdooInstallErrors.friendly(
          'Odoo is currently processing a scheduled action.\n'
          'Module operations are not possible at this time, please try again '
          'later or contact your system administrator.',
        ),
        contains('scheduled task'),
      );
    });

    test('a file the server lacks (an add-on newer than the Odoo core)', () {
      final text = OdooInstallErrors.friendly(
        "[Errno 2] No such file or directory: "
        "'/home/odoo/odoo20/odoo/addons/mail/static/src/img/odoobot.png'",
      );
      expect(text, contains('odoobot.png'));
      expect(text, contains('same version'));
      expect(text, isNot(contains('/home/odoo')));
      expect(text, isNot(contains('Errno')));
    });

    test('a dropped connection reads as its own message', () {
      const lost = OdooConnectionLost('the connection was lost');
      expect(lost.toString(), 'the connection was lost');
      expect(lost, isA<Exception>());
    });

    test('any other message is left as Odoo wrote it', () {
      const message = 'The auto-close period must be longer than the reminder.';
      expect(OdooInstallErrors.friendly(message), isNull);
      expect(OdooInstallErrors.reword(message), message);
    });

    test('matching ignores letter case', () {
      expect(
        OdooInstallErrors.friendly('CANNOT BE CALLED ON INIT OR NON LOADED REGISTRIES'),
        isNotNull,
      );
    });
  });
}
