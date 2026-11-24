import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_field_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No server is reachable here, so every `fields_get` fails: the resolver is
/// exercised on what it does when it cannot be answered, and on what it keeps.
void main() {
  Future<void> signInTo(String url, String database, int userId) async {
    SharedPreferences.setMockInitialValues({
      'url': url,
      'database': database,
      'userId': userId,
    });
  }

  setUp(() {
    OdooFieldResolver.clearCache();
  });

  group('when the server cannot be asked', () {
    setUp(() => signInTo('https://one.example', 'one', 1));

    test('a field older servers have is assumed present', () async {
      expect(
        await OdooFieldResolver.hasField('helpdesk.ticket', 'email_cc'),
        isTrue,
      );
    });

    test('a field only newer servers have is assumed absent', () async {
      expect(
        await OdooFieldResolver.hasField(
          'mail.activity',
          'role_id',
          assumeIfUnknown: false,
        ),
        isFalse,
      );
    });

    test('availableFields falls back to what the caller says is safe', () async {
      const wanted = ['id', 'name', 'role_id'];
      expect(
        await OdooFieldResolver.availableFields(
          'mail.activity',
          wanted,
          whenUnknown: const ['id', 'name'],
        ),
        ['id', 'name'],
      );
      expect(
        await OdooFieldResolver.availableFields('mail.activity', wanted),
        wanted,
      );
    });
  });

  group('answers belong to the server that gave them', () {
    test('an answer is kept while the same account is signed in', () async {
      await signInTo('https://one.example', 'one', 1);
      await OdooFieldResolver.hasField('mail.activity', 'role_id'); // sets scope
      OdooFieldResolver.debugSetFieldAnswer('mail.activity', 'role_id', true);

      expect(
        await OdooFieldResolver.hasField(
          'mail.activity',
          'role_id',
          assumeIfUnknown: false,
        ),
        isTrue,
      );
    });

    test('and dropped as soon as another server is signed in to', () async {
      // An Odoo 20 server says role_id exists...
      await signInTo('https://odoo20.example', 'db20', 1);
      await OdooFieldResolver.hasField('mail.activity', 'role_id');
      OdooFieldResolver.debugSetFieldAnswer('mail.activity', 'role_id', true);

      // ...then the app is signed in to an Odoo 17 one. The answer must not
      // follow it there: asking that server for role_id fails with a KeyError.
      await signInTo('https://odoo17.example', 'db17', 1);
      expect(
        await OdooFieldResolver.hasField(
          'mail.activity',
          'role_id',
          assumeIfUnknown: false,
        ),
        isFalse,
      );
    });

    test('also when only the database or the user differs', () async {
      await signInTo('https://one.example', 'a', 1);
      await OdooFieldResolver.hasField('mail.activity', 'phone');
      OdooFieldResolver.debugSetFieldAnswer('mail.activity', 'phone', true);

      await signInTo('https://one.example', 'b', 1);
      expect(
        await OdooFieldResolver.hasField(
          'mail.activity',
          'phone',
          assumeIfUnknown: false,
        ),
        isFalse,
      );

      OdooFieldResolver.debugSetFieldAnswer('mail.activity', 'phone', true);
      await signInTo('https://one.example', 'b', 2);
      expect(
        await OdooFieldResolver.hasField(
          'mail.activity',
          'phone',
          assumeIfUnknown: false,
        ),
        isFalse,
      );
    });
  });
}
