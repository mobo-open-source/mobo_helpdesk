import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_field_resolver.dart';
import 'package:mobo_helpdesk/di/injection_container.dart';
import 'package:mobo_helpdesk/features/tickets/domain/usecases/ticket_list_usecase.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/widgets/schedule_activity_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTicketListUseCase extends Mock implements TicketListUseCase {}

class MockTicketBloc extends MockBloc<TicketEvent, TicketState>
    implements TicketBloc {}

class FakeTicketEvent extends Fake implements TicketEvent {}

void main() {
  late MockTicketListUseCase useCase;
  late MockTicketBloc bloc;

  const types = [
    {'id': 4, 'name': 'To-Do', 'category': 'default'},
    {'id': 2, 'name': 'Call', 'category': 'phonecall'},
  ];
  const users = [
    {'id': 9, 'name': 'Claude Manager'},
    {'id': 10, 'name': 'Claude Agent'},
  ];

  /// A finder for a field's label, whether it is plain text or rich text (a
  /// required field's label carries a red asterisk).
  Finder label(String text) => find.byWidgetPredicate(
    (w) =>
        (w is Text && w.data == text) ||
        (w is RichText && w.text.toPlainText().startsWith(text)),
  );

  /// Whether the dialog's main button (Schedule / Save) can be pressed.
  bool canPress(WidgetTester tester, String title) {
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, title),
    );
    return button.onPressed != null;
  }

  Future<void> open(
    WidgetTester tester, {
    Map<String, dynamic>? activity,
    bool isEdit = false,
  }) async {
    final state = const TicketState(
      isLoading: false,
      activityTypes: types,
      users: users,
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<TicketState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<TicketBloc>.value(
            value: bloc,
            child: ScheduleActivityDialog(
              ticketId: 7,
              activity: activity,
              isEdit: isEdit,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What the server's activities have: Odoo 20 has a role and a phone number,
  /// earlier versions have neither.
  void serverHas({required bool role, required bool phone}) {
    OdooFieldResolver.clearCache();
    OdooFieldResolver.debugSetFieldAnswer('mail.activity', 'role_id', role);
    OdooFieldResolver.debugSetFieldAnswer('mail.activity', 'phone', phone);
  }

  setUpAll(() => registerFallbackValue(FakeTicketEvent()));

  setUp(() async {
    // The resolver keeps its answers per signed-in account, read from here.
    SharedPreferences.setMockInitialValues({});
    useCase = MockTicketListUseCase();
    bloc = MockTicketBloc();
    await sl.reset();
    sl.registerSingleton<TicketListUseCase>(useCase);

    when(() => useCase.loadActivityRoles()).thenAnswer(
      (_) async => [
        {'id': 1, 'name': 'Accounting Team'},
      ],
    );
    when(
      () => useCase.loadActivityDefaults(
        ticketId: any(named: 'ticketId'),
        activityTypeId: any(named: 'activityTypeId'),
        current: any(named: 'current'),
      ),
    ).thenAnswer(
      (_) async => {
        'activity_type_id': 4,
        'summary': 'To-Do',
        'date_deadline': '2026-10-06',
        'user_id': {'id': 9, 'name': 'Claude Manager'},
      },
    );
  });

  tearDown(() async => sl.reset());

  group('new activity on Odoo 20', () {
    setUp(() => serverHas(role: true, phone: true));

    testWidgets('opens on the type Odoo preselects, prefilled', (tester) async {
      await open(tester);

      // type field + summary field
      expect(find.text('To-Do'), findsNWidgets(2));
      expect(find.widgetWithText(TextField, 'To-Do'), findsOneWidget);
      expect(find.text('6-10-2026'), findsOneWidget);
      expect(find.text('Claude Manager'), findsOneWidget);
      expect(canPress(tester, 'Schedule'), isTrue);
    });

    testWidgets('shows the Odoo 20 fields: role, and no phone for a To-Do', (
      tester,
    ) async {
      await open(tester);

      for (final field in [
        'Activity Type',
        'Summary',
        'Due Date',
        'Assigned to',
        'Role',
        'Log a note',
      ]) {
        expect(label(field), findsWidgets, reason: field);
      }
      expect(label('Phone number'), findsNothing);
    });

    testWidgets('Schedule sends the Odoo 20 values', (tester) async {
      await open(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
      await tester.pump();

      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as ScheduleActivity;
      expect(event.data, {
        'res_id': 7,
        'activity_type_id': 4,
        'summary': 'To-Do',
        'date_deadline': '2026-10-06',
        'user_id': 9,
        'role_id': false,
        'note': '',
      });
    });
  });

  group('editing a call on Odoo 20', () {
    setUp(() => serverHas(role: true, phone: true));

    const call = {
      'id': 55,
      'summary': 'Ring back',
      'phone': '+1 555 0100',
      'activity_type_id': [2, 'Call'],
      'activity_category': 'phonecall',
      'user_id': [9, 'Claude Manager'],
      'role_id': false,
      'date_deadline': '2026-10-03',
      'note': false,
    };

    testWidgets('asks for the phone number and keeps Save off until a change', (
      tester,
    ) async {
      await open(tester, activity: call, isEdit: true);

      expect(label('Phone number'), findsWidgets);
      expect(find.widgetWithText(TextField, '+1 555 0100'), findsOneWidget);
      expect(canPress(tester, 'Save'), isFalse);
      // Editing does not ask Odoo to prefill over what is stored.
      verifyNever(
        () => useCase.loadActivityDefaults(
          ticketId: any(named: 'ticketId'),
          activityTypeId: any(named: 'activityTypeId'),
          current: any(named: 'current'),
        ),
      );
    });

    testWidgets('Save sends the phone number along', (tester) async {
      await open(tester, activity: call, isEdit: true);

      await tester.enterText(
        find.widgetWithText(TextField, '+1 555 0100'),
        '+1 555 0199',
      );
      await tester.pump();
      expect(canPress(tester, 'Save'), isTrue);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pump();

      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as UpdateActivity;
      expect(event.id, 55);
      expect(event.data, {
        'res_id': 7,
        'activity_type_id': 2,
        'summary': 'Ring back',
        'date_deadline': '2026-10-03',
        'user_id': 9,
        'role_id': false,
        'phone': '+1 555 0199',
        'note': '',
      });
    });

    testWidgets('a malformed phone number blocks Save', (tester) async {
      await open(tester, activity: call, isEdit: true);

      await tester.enterText(
        find.widgetWithText(TextField, '+1 555 0100'),
        '12',
      );
      await tester.pump();

      expect(canPress(tester, 'Save'), isFalse);
    });

    testWidgets('an activity for a role alone can be saved', (tester) async {
      await open(
        tester,
        activity: {
          ...call,
          'user_id': false,
          'role_id': [1, 'Accounting Team'],
        },
        isEdit: true,
      );
      expect(find.text('Accounting Team'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Ring back'),
        'Ring back soon',
      );
      await tester.pump();
      expect(canPress(tester, 'Save'), isTrue);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pump();
      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as UpdateActivity;
      expect(event.data['user_id'], false);
      expect(event.data['role_id'], 1);
    });
  });

  group('on Odoo 17, 18 and 19', () {
    setUp(() => serverHas(role: false, phone: false));

    testWidgets('has neither role nor phone, even for a call', (tester) async {
      await open(
        tester,
        activity: {
          'id': 55,
          'summary': 'Ring back',
          'activity_type_id': [2, 'Call'],
          'activity_category': 'phonecall',
          'user_id': [9, 'Claude Manager'],
          'date_deadline': '2026-10-03',
          'note': false,
        },
        isEdit: true,
      );

      expect(label('Role'), findsNothing);
      expect(label('Phone number'), findsNothing);
      for (final field in [
        'Activity Type',
        'Summary',
        'Due Date',
        'Assigned to',
        'Log a note',
      ]) {
        expect(label(field), findsWidgets, reason: field);
      }
    });

    testWidgets('saves exactly what those servers know', (tester) async {
      await open(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
      await tester.pump();

      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as ScheduleActivity;
      expect(event.data.containsKey('role_id'), isFalse);
      expect(event.data.containsKey('phone'), isFalse);
      expect(event.data['user_id'], 9);
    });
  });
}
