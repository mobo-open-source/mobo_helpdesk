import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_field_resolver.dart';
import 'package:mobo_helpdesk/core/widgets/mobo_checkbox.dart';
import 'package:mobo_helpdesk/di/injection_container.dart';
import 'package:mobo_helpdesk/features/teams/domain/usecases/team_form_usecase.dart';
import 'package:mobo_helpdesk/features/teams/presentation/bloc/team_bloc.dart';
import 'package:mobo_helpdesk/features/teams/presentation/pages/team_form.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTeamFormUseCase extends Mock implements TeamFormUseCase {}

class MockTeamBloc extends MockBloc<TeamEvent, TeamState> implements TeamBloc {}

class FakeTeamEvent extends Fake implements TeamEvent {}

void main() {
  late MockTeamFormUseCase useCase;
  late MockTeamBloc bloc;

  // What `helpdesk.team` has on each version (only the fields that differ).
  const odoo20 = {
    'use_giftcards',
    'use_product_replacements',
    'auto_close_ticket_reminder',
    'auto_close_reminder_delay',
  };
  const odoo19 = {'use_rating', 'use_giftcards', 'use_product_replacements'};
  const odoo17 = {'use_rating', 'portal_show_rating'};

  Finder label(String text) => find.byWidgetPredicate(
    (w) =>
        (w is Text && w.data == text) ||
        (w is RichText && w.text.toPlainText().startsWith(text)),
  );

  /// The checkbox on the same row as [text].
  Finder checkboxOf(String text) => find
      .descendant(
        of: find
            .ancestor(of: label(text), matching: find.byType(Row))
            .first,
        matching: find.byType(MoboCheckbox),
      )
      .first;

  bool canSave(WidgetTester tester) =>
      tester
          .widget<ElevatedButton>(find.bySubtype<ElevatedButton>())
          .onPressed !=
      null;

  Future<void> open(
    WidgetTester tester,
    Set<String> serverFields, {
    TeamState state = const TeamState(isLoading: false),
  }) async {
    // The blocking "saving" card has a spinner that never stops animating.
    final settles = !state.isSaving;
    OdooFieldResolver.clearCache();
    OdooFieldResolver.debugSetAvailableFields('helpdesk.team', serverFields);

    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<TeamState>.empty(), initialState: state);

    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TeamBloc>.value(
          value: bloc,
          child: const TeamForm(isCreate: true),
        ),
      ),
    );
    if (settles) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> toggle(WidgetTester tester, String text) async {
    final box = checkboxOf(text);
    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pumpAndSettle();
  }

  Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  setUpAll(() => registerFallbackValue(FakeTeamEvent()));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    useCase = MockTeamFormUseCase();
    bloc = MockTeamBloc();
    await sl.reset();
    sl.registerSingleton<TeamFormUseCase>(useCase);
    when(() => useCase.loadReminderTemplates()).thenAnswer(
      (_) async => [
        {'id': 9, 'name': 'Auto-close reminder'},
      ],
    );
    when(() => useCase.optionsNeedingInstall(any())).thenAnswer((_) async => []);
    when(() => useCase.loadTeamDefaults()).thenAnswer(
      (_) async => {
        'auto_close_day': 7,
        'auto_close_ticket_reminder': true,
        'auto_close_reminder_delay': 2,
        'reminder_email_template_id': 9,
      },
    );
  });

  tearDown(() async => sl.reset());

  group('create a team on Odoo 20', () {
    testWidgets('with only a name: sends what Odoo can accept', (tester) async {
      await open(tester, odoo20);

      await typeInto(tester, find.byType(TextField).first, 'uhh');
      expect(canSave(tester), isTrue);

      await tester.tap(find.bySubtype<ElevatedButton>());
      await tester.pump();

      final event =
          verify(() => bloc.add(captureAny())).captured.single as CreateTeam;
      final data = event.data;
      expect(data['name'], 'uhh');
      // Followers are partners, sent as message_partner_ids.
      expect(data.containsKey('message_partner_ids'), isTrue);
      expect(data.containsKey('message_follower_ids'), isFalse);
      // An untouched period goes as empty text; the datasource leaves it out
      // so Odoo's own default applies (it was read as 0 before, which Odoo 20
      // refuses next to its reminder).
      expect(data['auto_close_day'], '');
      expect(data['auto_close_reminder_delay'], '');
      // The reminder starts as Odoo has it: on, with its template.
      expect(data['auto_close_ticket_reminder'], true);
      expect(data['reminder_email_template_id'], 9);
    });

    testWidgets('Automatic Closing can be turned on and off again', (
      tester,
    ) async {
      await open(tester, odoo20);

      expect(label('Auto-Close Reminder'), findsNothing);
      await toggle(tester, 'Automatic Closing');
      expect(label('Auto-Close Reminder'), findsWidgets);
      expect(label('Email Template'), findsWidgets);

      // It used to switch on and never off.
      await toggle(tester, 'Automatic Closing');
      expect(label('Auto-Close Reminder'), findsNothing);
    });

    testWidgets('a reminder not shorter than the period blocks saving', (
      tester,
    ) async {
      await open(tester, odoo20);
      await typeInto(tester, find.byType(TextField).first, 'Support');
      await toggle(tester, 'Automatic Closing');

      // The period field is the one right above the reminder delay.
      final fields = find.byType(TextField);
      final count = tester.widgetList(fields).length;
      // name, description, alias name, days, reminder delay (in tree order)
      expect(count, greaterThanOrEqualTo(5));
      final periodField = fields.at(count - 2);
      final delayField = fields.at(count - 1);

      // 2 days of inactivity against Odoo's default 2-day reminder
      await typeInto(tester, periodField, '2');
      expect(canSave(tester), isFalse);
      expect(
        find.textContaining('reminder must be sent before the ticket closes'),
        findsWidgets,
      );

      // 10 days is fine
      await typeInto(tester, periodField, '10');
      expect(canSave(tester), isTrue);

      // and a longer reminder delay is not
      await typeInto(tester, delayField, '12');
      expect(canSave(tester), isFalse);
      await typeInto(tester, delayField, '3');
      expect(canSave(tester), isTrue);
    });
  });


  group('layout of the Channels card (Email Alias)', () {
    testWidgets('the alias fields are labelled, equally tall and evenly spaced', (
      tester,
    ) async {
      await open(tester, odoo20);

      // Every field in the stack carries its label.
      for (final field in ['Alias Name', 'Alias Domain', 'Accept Emails From']) {
        expect(label(field), findsWidgets, reason: field);
      }

      final name = tester.getRect(label('Alias Name').first);
      final domain = tester.getRect(label('Alias Domain').first);
      final accept = tester.getRect(label('Accept Emails From').first);

      // label -> field -> gap -> next label: the same distance every time, which
      // can only hold if the text field and the dropdowns are the same height
      // and nothing adds space on one side only.
      final step1 = domain.top - name.top;
      final step2 = accept.top - domain.top;
      expect(step1, closeTo(step2, 0.5), reason: 'uneven spacing');
      // label (its own height + 8) + a 48px field + the shared 14px gap
      expect(step1, closeTo(name.height + 8 + 48 + 14, 1.0));
    });

    testWidgets('the text field is as tall as the dropdowns (48px)', (
      tester,
    ) async {
      await open(tester, odoo20);
      final aliasField = find
          .ancestor(
            of: find.byType(TextField).at(2), // name, description, alias
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getRect(aliasField).height, closeTo(48, 0.5));
    });

    testWidgets('a checkbox\'s label and its hint start at the same x', (
      tester,
    ) async {
      await open(tester, odoo20);
      final title = tester.getRect(label('Email Alias').first);
      final hint = tester.getRect(
        find.text('Create tickets by sending an email to an alias').first,
      );
      expect(title.left, closeTo(hint.left, 0.5));
    });
  });


  group('saving a team that needs apps installed', () {
    /// Name typed, Timesheets (and optionally more) switched on, Save pressed.
    Future<void> saveWith(
      WidgetTester tester,
      List<String> optionLabels,
    ) async {
      await open(tester, odoo20);
      await typeInto(tester, find.byType(TextField).first, 'Support');
      for (final option in optionLabels) {
        await toggle(tester, option);
      }
      await tester.tap(find.bySubtype<ElevatedButton>());
      await tester.pumpAndSettle();
    }

    testWidgets('asks the server about the options that are on', (tester) async {
      await saveWith(tester, ['Timesheets']);
      final asked =
          verify(() => useCase.optionsNeedingInstall(captureAny())).captured.single
              as List<String>;
      expect(asked, contains('use_helpdesk_timesheet'));
      expect(asked, isNot(contains('use_coupons')));
    });

    testWidgets('the loading screen is up the moment Create is tapped', (
      tester,
    ) async {
      // The server has not answered yet whether an app is needed.
      final answer = Completer<List<String>>();
      when(() => useCase.optionsNeedingInstall(any())).thenAnswer((_) => answer.future);

      await open(tester, odoo20);
      await typeInto(tester, find.byType(TextField).first, 'Support');
      expect(find.text('Creating Team'), findsNothing);

      await tester.tap(find.bySubtype<ElevatedButton>());
      await tester.pump();

      expect(find.text('Creating Team'), findsOneWidget, reason: 'tapping must answer at once');
      verifyNever(() => bloc.add(any()));

      // Back must not open "Discard changes" over a save that is starting.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Discard Changes?'), findsNothing);

      answer.complete(<String>[]);
      await tester.pump();
      await tester.pump();

      verify(() => bloc.add(any(that: isA<CreateTeam>()))).called(1);
    });

    testWidgets('the loading screen is gone when the question is asked', (
      tester,
    ) async {
      when(() => useCase.optionsNeedingInstall(any())).thenAnswer(
        (_) async => ['use_helpdesk_timesheet'],
      );
      await saveWith(tester, ['Timesheets']);

      expect(find.text('Install required apps?'), findsOneWidget);
      expect(find.text('Creating Team'), findsNothing);
    });

    testWidgets('nothing to install: saves straight away, no question', (
      tester,
    ) async {
      await saveWith(tester, ['Timesheets']); // server says [] by default
      expect(label('Install required apps?'), findsNothing);
      final event =
          verify(() => bloc.add(captureAny())).captured.single as CreateTeam;
      expect(event.installs, isFalse);
    });

    testWidgets('an app needed: says which options, and waits for a yes', (
      tester,
    ) async {
      when(() => useCase.optionsNeedingInstall(any())).thenAnswer(
        (_) async => ['use_helpdesk_timesheet', 'use_website_helpdesk_forum'],
      );
      await saveWith(tester, ['Timesheets']);

      expect(find.text('Install required apps?'), findsOneWidget);
      expect(
        find.textContaining('Timesheets and Community Forum need more Odoo apps'),
        findsOneWidget,
      );
      expect(find.text('Install'), findsOneWidget);
      // nothing has been sent while the question is open
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('Cancel sends nothing and leaves the form as it was', (
      tester,
    ) async {
      when(() => useCase.optionsNeedingInstall(any())).thenAnswer(
        (_) async => ['use_helpdesk_timesheet'],
      );
      await saveWith(tester, ['Timesheets']);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
      expect(find.text('Install required apps?'), findsNothing);
      expect(canSave(tester), isTrue, reason: 'the user can still change their mind');
    });

    testWidgets('the keyboard is closed for the question and stays closed', (
      tester,
    ) async {
      when(() => useCase.optionsNeedingInstall(any())).thenAnswer(
        (_) async => ['use_helpdesk_timesheet'],
      );
      await saveWith(tester, ['Timesheets']);
      // The Name field was typed into just before, so it had focus.
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // Closing the dialog must not hand focus back to the field.
      expect(tester.testTextInput.isVisible, isFalse);
      expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()));
    });

    testWidgets('Install sends the team marked as installing', (
      tester,
    ) async {
      when(() => useCase.optionsNeedingInstall(any())).thenAnswer(
        (_) async => ['use_helpdesk_timesheet'],
      );
      await saveWith(tester, ['Timesheets']);

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      final event =
          verify(() => bloc.add(captureAny())).captured.single as CreateTeam;
      expect(event.installs, isTrue);
      expect(event.data['name'], 'Support');
      expect(event.data['use_helpdesk_timesheet'], isTrue);
    });

    testWidgets('a failed check does not stop the save', (tester) async {
      when(() => useCase.optionsNeedingInstall(any())).thenThrow(Exception('offline'));
      await saveWith(tester, ['Timesheets']);

      final event =
          verify(() => bloc.add(captureAny())).captured.single as CreateTeam;
      expect(event.installs, isFalse);
    });

    testWidgets('toggling Timesheets or Website Form no longer installs on its own', (
      tester,
    ) async {
      await open(tester, odoo20);
      await toggle(tester, 'Timesheets');
      await toggle(tester, 'Website Form');
      // only the save, after asking, installs anything
      verifyNever(() => bloc.add(any()));
    });
  });

  group('the blocking screen while saving', () {
    testWidgets('says "Installing apps" and that it takes a while', (tester) async {
      await open(
        tester,
        odoo20,
        state: const TeamState(
          isLoading: false,
          isSaving: true,
          savingMessage: 'Installing apps',
          savingHint: 'This can take a few minutes. Keep the app open.',
        ),
      );
      expect(find.text('Installing apps'), findsOneWidget);
      expect(find.text('This can take a few minutes. Keep the app open.'), findsOneWidget);
      expect(find.text('Creating Team'), findsNothing);
    });

    testWidgets('a plain save keeps the usual text', (tester) async {
      await open(
        tester,
        odoo20,
        state: const TeamState(isLoading: false, isSaving: true),
      );
      expect(find.text('Creating Team'), findsOneWidget);
      expect(find.text('Please wait while we create the team'), findsOneWidget);
    });

    testWidgets('while it waits for another installation it says so', (tester) async {
      await open(
        tester,
        odoo20,
        state: const TeamState(
          isLoading: false,
          isSaving: true,
          savingMessage: 'Waiting for the server',
          savingHint: 'Another installation is still running.',
        ),
      );
      expect(find.text('Waiting for the server'), findsOneWidget);
    });
  });

  group('settings that differ by version', () {
    testWidgets('Odoo 20 and 19 offer gift cards and replacements', (
      tester,
    ) async {
      await open(tester, odoo19);
      expect(label('Gift Cards'), findsWidgets);
      expect(label('Replacements'), findsWidgets);
    });

    testWidgets('Odoo 17 and 18 do not', (tester) async {
      await open(tester, odoo17);
      expect(label('Gift Cards'), findsNothing);
      expect(label('Replacements'), findsNothing);
    });

    testWidgets('Odoo 17 can publish a team\'s ratings on the website', (
      tester,
    ) async {
      await open(tester, odoo17);
      expect(label('Customer Ratings'), findsWidgets);
      await toggle(tester, 'Customer Ratings');
      expect(
        label("Publish this team's ratings on your website"),
        findsWidgets,
      );
    });

    testWidgets('Odoo 20 has no team rating setting (it moved to stages)', (
      tester,
    ) async {
      await open(tester, odoo20);
      expect(label('Customer Ratings'), findsNothing);
    });

    testWidgets('the reminder only exists on Odoo 20', (tester) async {
      await open(tester, odoo19);
      await toggle(tester, 'Automatic Closing');
      expect(label('Auto-Close Reminder'), findsNothing);
    });

    testWidgets('an older team is saved without Odoo 20 values being needed', (
      tester,
    ) async {
      await open(tester, odoo17);
      await typeInto(tester, find.byType(TextField).first, 'Old school');
      await tester.tap(find.bySubtype<ElevatedButton>());
      await tester.pump();
      final event =
          verify(() => bloc.add(captureAny())).captured.single as CreateTeam;
      expect(event.data['name'], 'Old school');
    });
  });

  group('after a save the server kept although installing its apps failed', () {
    const base = TeamState(isLoading: false);
    final failed = base.copyWith(
      message:
          'The team "Support" was created, but the apps it needs could not be '
          'installed.\n\nThe server could not finish the installation: a file '
          'it needs is missing (odoobot.png).',
      isError: true,
      serverSaved: true,
    );

    /// Opens the form from a screen standing in for the list, so that what
    /// the form returns to it can be seen.
    Future<ValueNotifier<Object?>> openFrom(WidgetTester tester, TeamState emitted) async {
      OdooFieldResolver.clearCache();
      OdooFieldResolver.debugSetAvailableFields('helpdesk.team', odoo20);
      when(() => bloc.state).thenReturn(base);
      whenListen(bloc, Stream.value(emitted), initialState: base);
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final result = ValueNotifier<Object?>('nothing returned');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result.value = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider<TeamBloc>.value(
                        value: bloc,
                        child: const TeamForm(isCreate: true),
                      ),
                    ),
                  );
                },
                child: const Text('list'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('list'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a new team: says what happened, then returns to the list to reload it', (
      tester,
    ) async {
      final result = await openFrom(tester, failed);

      expect(find.text('Apps not installed'), findsOneWidget);
      expect(find.textContaining('was created, but'), findsOneWidget);
      expect(find.textContaining('odoobot.png'), findsOneWidget);
      // clean white, like the login notices
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, Colors.white);
      expect(result.value, 'nothing returned', reason: 'waits for the user to read it');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result.value, true, reason: 'the list reloads and shows the team');
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('an ordinary error stays a message and keeps the form', (
      tester,
    ) async {
      final plain = base.copyWith(message: 'Alias is already in use', isError: true);
      final result = await openFrom(tester, plain);

      expect(find.text('Apps not installed'), findsNothing);
      expect(find.byType(TeamForm), findsOneWidget);
      expect(result.value, 'nothing returned');
    });
  });
}
