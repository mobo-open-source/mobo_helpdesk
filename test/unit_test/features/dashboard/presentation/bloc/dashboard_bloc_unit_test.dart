import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/dashboard/domain/entities/dashboard_entity.dart';
import 'package:mobo_helpdesk/features/dashboard/domain/entities/rating_entity.dart';
import 'package:mobo_helpdesk/features/dashboard/domain/usecases/dashboard_usecase.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardUseCase extends Mock implements DashboardUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DashboardBloc bloc;
  late MockDashboardUseCase mockDashboardUseCase;

  setUp(() {
    mockDashboardUseCase = MockDashboardUseCase();
    bloc = DashboardBloc(mockDashboardUseCase);
  });

  group('DashboardBloc - Load Dashboard Data', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits loading then dashboard data on success',
      build: () {
        when(
          () => mockDashboardUseCase.loadDashboard(),
        ).thenAnswer((_) async => {'data': <DashboardEntity>[]});

        return bloc;
      },
      act: (bloc) => bloc.add(DashboardLoad()),
      expect: () => [
        isA<DashboardState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DashboardState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.dashboard, 'dashboard', isA<List>()),
      ],
      verify: (_) {
        verify(() => mockDashboardUseCase.loadDashboard()).called(1);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits map error on failure',
      build: () {
        when(
          () => mockDashboardUseCase.loadDashboard(),
        ).thenThrow({'title': 'Error', 'description': 'Failed'});
        return bloc;
      },
      act: (bloc) => bloc.add(DashboardLoad()),
      expect: () => [
        isA<DashboardState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DashboardState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error?['title'], 'title', 'Error')
            .having((s) => s.error?['description'], 'description', 'Failed'),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits generic error on exception',
      build: () {
        when(
          () => mockDashboardUseCase.loadDashboard(),
        ).thenThrow(Exception('Network failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(DashboardLoad()),
      expect: () => [
        isA<DashboardState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DashboardState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error?['title'], 'title', 'Error')
            .having(
              (s) => s.error?['description'],
              'description',
              contains('Network failed'),
            ),
      ],
    );
  });

  group('DashboardBloc - Update Dashboard Target Values', () {
    blocTest<DashboardBloc, DashboardState>(
      'calls updateTarget and triggers DashboardLoad on success',
      build: () {
        when(
          () => mockDashboardUseCase.updateTarget(
            teamId: any(named: 'teamId'),
            field: any(named: 'field'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTargetEvent(teamId: 1, field: 'helpdesk_target_closed', value: 3),
      ),
      verify: (_) async {
        verify(
          () => mockDashboardUseCase.updateTarget(
            teamId: 1,
            field: 'helpdesk_target_closed',
            value: 3,
          ),
        ).called(1);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits error when updateTarget throws Map error',
      build: () {
        when(
          () => mockDashboardUseCase.updateTarget(
            teamId: any(named: 'teamId'),
            field: any(named: 'field'),
            value: any(named: 'value'),
          ),
        ).thenThrow({'title': 'Error', 'description': 'Failed'});
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTargetEvent(teamId: 1, field: 'helpdesk_target_closed', value: 3),
      ),
      expect: () => [
        isA<DashboardState>()
            .having((s) => s.error, 'error', isNotNull)
            .having((s) => s.isLoading, 'isLoading', false),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockDashboardUseCase.updateTarget(
            teamId: any(named: 'teamId'),
            field: any(named: 'field'),
            value: any(named: 'value'),
          ),
        ).thenThrow(Exception('Failed'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTargetEvent(teamId: 1, field: 'helpdesk_target_closed', value: 3),
      ),
      expect: () => [
        isA<DashboardState>()
            .having((s) => s.error, 'error', isNotNull)
            .having((s) => s.isLoading, 'isLoading', false),
      ],
    );
  });

  group('DashboardBloc - Delete Rating', () {
    blocTest<DashboardBloc, DashboardState>(
      'calls deleteRating and triggers RatingsLoad and emits success message on success',
      build: () {
        when(
          () => mockDashboardUseCase.deleteRating(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockDashboardUseCase.loadRatings(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
            search: any(named: 'search'),
            customDomain: any(named: 'customDomain'),
          ),
        ).thenAnswer((_) async => {'data': <RatingEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteRating(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<DashboardState>()
            .having((s) => s.message, 'message', 'Rating deleted successfully')
            .having((s) => s.isError, 'isError', false),
        isA<DashboardState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockDashboardUseCase.deleteRating(1)).called(1);
        verify(
          () => mockDashboardUseCase.loadRatings(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
            search: any(named: 'search'),
            customDomain: any(named: 'customDomain'),
          ),
        ).called(1);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockDashboardUseCase.deleteRating(any()),
        ).thenThrow(Exception('Failed to delete'));
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteRating(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<DashboardState>()
            .having((s) => s.message, 'message', 'Failed to delete')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockDashboardUseCase.deleteRating(1)).called(1);
      },
    );
  });
}
