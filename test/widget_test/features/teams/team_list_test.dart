import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/teams/presentation/bloc/team_bloc.dart';
import 'package:mobo_helpdesk/features/teams/presentation/pages/team_list.dart';
import 'package:mocktail/mocktail.dart';

class MockTeamBloc extends MockBloc<TeamEvent, TeamState> implements TeamBloc {}

class FakeTeamEvent extends Fake implements TeamEvent {}

void main() {
  late MockTeamBloc bloc;
  late StreamController<TeamState> states;

  setUpAll(() => registerFallbackValue(FakeTeamEvent()));

  setUp(() {
    bloc = MockTeamBloc();
    states = StreamController<TeamState>.broadcast();
    addTearDown(states.close);
  });

  /// The team list showing [state], with the bloc's later states coming from
  /// [states].
  Future<void> open(WidgetTester tester, TeamState state) async {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, states.stream, initialState: state);

    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TeamBloc>.value(value: bloc, child: const TeamList()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Pulls the content down as a finger would, and lets it settle on the
  /// refresh spinner.
  Future<void> pullDown(WidgetTester tester, Finder content) async {
    await tester.fling(content, const Offset(0, 500), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  const empty = TeamState(isLoading: false, data: [], page: 1, total: 0);

  group('team list: pull to refresh', () {
    testWidgets('an empty list can be pulled down to reload it', (tester) async {
      await open(tester, empty);
      expect(find.text('No Teams found'), findsOneWidget);

      await pullDown(tester, find.text('No Teams found'));

      final event = verify(() => bloc.add(captureAny())).captured.single;
      expect(event, isA<TeamsLoad>());
      expect((event as TeamsLoad).page, 1);
      expect(event.filters, isNull, reason: 'null keeps the filters in use');
      expect(
        event.showSkeleton,
        isTrue,
        reason: 'the list shows its skeleton while it reloads',
      );

      // finish the reload so no timer is left running
      states.add(empty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the spinner stays until the reload has finished', (tester) async {
      await open(tester, empty);

      await pullDown(tester, find.text('No Teams found'));
      // The server has not answered: still reloading, as the bloc says.
      states.add(empty.copyWith(isPaginationLoading: true));
      // In small steps: the spinner closes with an animation that needs frames,
      // so one long pump would not show it going.
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        find.byType(RefreshProgressIndicator),
        findsOneWidget,
        reason: 'a slow server must not make the spinner vanish early',
      );

      states.add(empty); // answered
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });
  });
}
