import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/rating/domain/usecases/review_usecase.dart';
import 'package:mobo_helpdesk/features/sla_policy/domain/entities/sla_policy_entity.dart';
import 'package:mobo_helpdesk/features/sla_policy/domain/usecases/sla_policy_form_usecase.dart';
import 'package:mobo_helpdesk/features/sla_policy/domain/usecases/sla_policy_list_usecase.dart';
import 'package:mobo_helpdesk/features/sla_policy/presentation/bloc/sla_policy_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSlaPolicyListUseCase extends Mock implements SlaPolicyListUseCase {}

class MockSlaPolicyFormUseCase extends Mock implements SlaPolicyFormUseCase {}

class MockTrackEvent extends Mock implements TrackEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SlaPolicyBloc bloc;
  late MockSlaPolicyListUseCase mockSlaPolicyListUseCase;
  late MockSlaPolicyFormUseCase mockSlaPolicyFormUseCase;
  late MockTrackEvent mockTrackEvent;

  setUp(() {
    mockSlaPolicyListUseCase = MockSlaPolicyListUseCase();
    mockSlaPolicyFormUseCase = MockSlaPolicyFormUseCase();
    mockTrackEvent = MockTrackEvent();
    bloc = SlaPolicyBloc(
      mockSlaPolicyListUseCase,
      mockSlaPolicyFormUseCase,
      mockTrackEvent,
    );
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues({'serverVersion': '17'});
  });

  group('SlaPolicyBloc - Load SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits loading then success when loadPolicies succeeds',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            search: any(named: 'search'),
            customDomain: any(named: 'customDomain'),
          ),
        ).thenAnswer((_) async => {'data': <SlaPolicyEntity>[], 'total': 0});

        return bloc;
      },
      act: (bloc) => bloc.add(SlaPolicyLoad(1)),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isLoading, 'isLoading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isPaginationLoading, 'isPaginationLoading', false)
            .having((s) => s.data, 'data', isEmpty)
            .having((s) => s.total, 'total', 0)
            .having((s) => s.page, 'page', 1),
      ],
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when loadPolicies fails',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            search: any(named: 'search'),
            customDomain: any(named: 'customDomain'),
          ),
        ).thenThrow(Exception('Failed to load'));

        return bloc;
      },
      act: (bloc) => bloc.add(SlaPolicyLoad(1)),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isLoading, 'isLoading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });

  group('SlaPolicyBloc - Delete SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'calls deletePolicy and triggers SlaPolicyLoad and emits success message on success',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.deletePolicy(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
          ),
        ).thenAnswer((_) async => {'data': <SlaPolicyEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteSlaPolicy(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>()
            .having(
              (s) => s.message,
              'message',
              'Sla policy deleted successfully',
            )
            .having((s) => s.isError, 'isError', false),
        isA<SlaPolicyState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyListUseCase.deletePolicy(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
          ),
        ).called(1);
      },
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.deletePolicy(any()),
        ).thenThrow(Exception('Failed to delete'));
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteSlaPolicy(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>()
            .having((s) => s.message, 'message', 'Failed to delete')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyListUseCase.deletePolicy(1)).called(1);
      },
    );
  });

  group('SlaPolicyBloc - Archive SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'calls archivePolicy and triggers SlaPolicyLoad and emits success message on success',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.archivePolicy(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
          ),
        ).thenAnswer((_) async => {'data': <SlaPolicyEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(ArchiveSlaPolicy(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>()
            .having(
              (s) => s.message,
              'message',
              'Sla policy archived successfully',
            )
            .having((s) => s.isError, 'isError', false),
        isA<SlaPolicyState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyListUseCase.archivePolicy(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
          ),
        ).called(1);
      },
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.archivePolicy(any()),
        ).thenThrow(Exception('Failed to archive'));
        return bloc;
      },
      act: (bloc) => bloc.add(ArchiveSlaPolicy(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>()
            .having((s) => s.message, 'message', 'Failed to archive')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyListUseCase.archivePolicy(1)).called(1);
      },
    );
  });

  group('SlaPolicyBloc - Unarchive SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'calls unArchivePolicy and triggers SlaPolicyLoad and emits success message on success',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.unArchivePolicy(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
          ),
        ).thenAnswer((_) async => {'data': <SlaPolicyEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(UnArchiveSlaPolicy(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>()
            .having(
              (s) => s.message,
              'message',
              'Sla policy unarchived successfully',
            )
            .having((s) => s.isError, 'isError', false),
        isA<SlaPolicyState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyListUseCase.unArchivePolicy(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockSlaPolicyListUseCase.loadPolicies(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
          ),
        ).called(1);
      },
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockSlaPolicyListUseCase.unArchivePolicy(any()),
        ).thenThrow(Exception('Failed to unarchive'));
        return bloc;
      },
      act: (bloc) => bloc.add(UnArchiveSlaPolicy(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>()
            .having((s) => s.message, 'message', 'Failed to unarchive')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyListUseCase.unArchivePolicy(1)).called(1);
      },
    );
  });

  group('SlaPolicyBloc - Load Single SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits loading then success when all APIs succeed',
      build: () {
        when(() => mockSlaPolicyFormUseCase.loadPolicyData(any())).thenAnswer(
          (_) async => [
            {
              'team_id': [1, 'Team A'],
              'stage_id': [2, 'Stage A'],
              'tag_ids': [1],
              'ticket_type_ids': [10],
              'partner_ids': [100],
              'exclude_stage_ids': [5],
            },
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadTypes()).thenAnswer(
          (_) async => [
            {'id': 10, 'name': 'Type A'},
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadTags()).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Tag A'},
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadCustomers()).thenAnswer(
          (_) async => [
            {'id': 100, 'name': 'Customer A'},
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadHelpdeskTeam()).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Team A'},
          ],
        );

        when(
          () => mockSlaPolicyFormUseCase.loadReachStages(any(), any()),
        ).thenAnswer(
          (_) async => [
            {'id': 2, 'name': 'Stage A'},
          ],
        );

        when(
          () => mockSlaPolicyFormUseCase.loadExcludingStages(any(), any()),
        ).thenAnswer(
          (_) async => [
            {'id': 5, 'name': 'Stage B'},
          ],
        );

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSinglePolicy(1)),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isLoading, 'loading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.selectedPolicy, 'policy', isNotNull)
            .having((s) => s.selectedTeam, 'team', isNotNull)
            .having((s) => s.selectedTags, 'tags', isNotNull)
            .having((s) => s.selectedTags?.length, 'tags length', 1)
            .having((s) => s.selectedCustomers, 'customers', isNotNull)
            .having((s) => s.selectedCustomers?.length, 'customers length', 1),
      ],
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'handles empty policy data safely',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.loadPolicyData(any()),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadTypes(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadTags(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadCustomers(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadHelpdeskTeam(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadReachStages(any(), any()),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadExcludingStages(any(), any()),
        ).thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSinglePolicy(1)),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isLoading, 'loading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.selectedPolicy, 'policy', isNull),
      ],
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when loadPolicyData fails',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.loadPolicyData(any()),
        ).thenThrow(Exception('Failed to load'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSinglePolicy(1)),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isLoading, 'loading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.error?['description'],
              'error',
              contains('Failed'),
            ),
      ],
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'continues with empty types when loadTypes fails',
      build: () {
        when(() => mockSlaPolicyFormUseCase.loadPolicyData(any())).thenAnswer(
          (_) async => [
            {
              'team_id': [1, 'Team A'],
              'stage_id': [2, 'Stage A'],
              'tag_ids': [],
              'ticket_type_ids': [],
              'partner_ids': [],
              'exclude_stage_ids': [],
            },
          ],
        );

        when(
          () => mockSlaPolicyFormUseCase.loadTypes(),
        ).thenThrow(Exception('Types failed'));

        when(
          () => mockSlaPolicyFormUseCase.loadTags(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadCustomers(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadHelpdeskTeam(),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadReachStages(any(), any()),
        ).thenAnswer((_) async => []);

        when(
          () => mockSlaPolicyFormUseCase.loadExcludingStages(any(), any()),
        ).thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSinglePolicy(1)),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isLoading, 'loading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.types, 'types', isEmpty),
      ],
    );
  });

  group('SlaPolicyBloc - Load create data for SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits loading then success with all data when APIs succeed',
      build: () {
        when(() => mockSlaPolicyFormUseCase.loadHelpdeskTeam()).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Team A'},
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadTypes()).thenAnswer(
          (_) async => [
            {'id': 10, 'name': 'Type A'},
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadTags()).thenAnswer(
          (_) async => [
            {'id': 2, 'name': 'Tag A'},
          ],
        );

        when(() => mockSlaPolicyFormUseCase.loadCustomers()).thenAnswer(
          (_) async => [
            {'id': 100, 'name': 'Customer A'},
          ],
        );

        return bloc;
      },
      act: (bloc) => bloc.add(LoadPolicyCreateData()),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isFormLoading, 'loading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isFormLoading, 'loading', false)
            .having((s) => s.helpdeskTeam?.length ?? 0, 'team', 1)
            .having((s) => s.types?.length ?? 0, 'types', 1)
            .having((s) => s.tags?.length ?? 0, 'tags', 1)
            .having((s) => s.customers?.length ?? 0, 'customers', 1),
      ],
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits success with empty lists when all APIs fail',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.loadHelpdeskTeam(),
        ).thenThrow(Exception());

        when(() => mockSlaPolicyFormUseCase.loadTypes()).thenThrow(Exception());

        when(() => mockSlaPolicyFormUseCase.loadTags()).thenThrow(Exception());

        when(
          () => mockSlaPolicyFormUseCase.loadCustomers(),
        ).thenThrow(Exception());

        return bloc;
      },
      act: (bloc) => bloc.add(LoadPolicyCreateData()),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isFormLoading, 'loading', true),
        isA<SlaPolicyState>()
            .having((s) => s.isFormLoading, 'loading', false)
            .having((s) => s.helpdeskTeam, 'team', isEmpty)
            .having((s) => s.types, 'types', isEmpty)
            .having((s) => s.tags, 'tags', isEmpty)
            .having((s) => s.customers, 'customers', isEmpty),
      ],
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits loading false when unexpected error occurs',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.loadHelpdeskTeam(),
        ).thenAnswer((_) async => throw Exception('Unexpected'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadPolicyCreateData()),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isFormLoading, 'loading', true),
        isA<SlaPolicyState>().having((s) => s.isFormLoading, 'loading', false),
      ],
    );
  });

  group('SlaPolicyBloc - Create SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits success message when policy create succeed',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.createPolicy(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        CreatePolicy({
          'name': '5 days to start',
          'description': '5 days to start',
          'time': '10',
          'priority': 3,
          'team_id': 1,
          'stage_id': 1,
          'partner_ids': [1, 2, 3],
          'tag_ids': [1, 2, 3],
          'exclude_stage_ids': [1, 2, 3],
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isSaving, 'isSaving', true),
        isA<SlaPolicyState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.message,
              'message',
              'SLA Policy created successfully',
            )
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyFormUseCase.createPolicy(any())).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.createPolicy(any()),
        ).thenThrow(Exception('Failed to create'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        CreatePolicy({
          'name': '5 days to start',
          'description': '5 days to start',
          'time': '10',
          'priority': 3,
          'team_id': 1,
          'stage_id': 1,
          'partner_ids': [1, 2, 3],
          'tag_ids': [1, 2, 3],
          'exclude_stage_ids': [1, 2, 3],
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isSaving, 'isSaving', true),
        isA<SlaPolicyState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to create')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockSlaPolicyFormUseCase.createPolicy(any())).called(1);
      },
    );
  });

  group('SlaPolicyBloc - Update SLA Policy', () {
    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits success message when policy update succeed',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.updatePolicy(any(), any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdatePolicy(1, {
          'name': '10 days to start',
          'description': '5 days to start',
          'time': '3',
          'priority': 3,
          'team_id': 1,
          'stage_id': 1,
          'partner_ids': [1, 2, 3],
          'tag_ids': [1, 2, 3],
          'exclude_stage_ids': [1, 2, 3],
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isSaving, 'isSaving', true),
        isA<SlaPolicyState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.message,
              'message',
              'SLA Policy updated successfully',
            )
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(
          () => mockSlaPolicyFormUseCase.updatePolicy(any(), any()),
        ).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<SlaPolicyBloc, SlaPolicyState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockSlaPolicyFormUseCase.updatePolicy(any(), any()),
        ).thenThrow(Exception('Failed to update'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdatePolicy(1, {
          'name': '5 days to start',
          'description': '5 days to start',
          'time': '10',
          'priority': 3,
          'team_id': 1,
          'stage_id': 1,
          'partner_ids': [1, 2, 3],
          'tag_ids': [1, 2, 3],
          'exclude_stage_ids': [1, 2, 3],
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<SlaPolicyState>().having((s) => s.isSaving, 'isSaving', true),
        isA<SlaPolicyState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to update')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(
          () => mockSlaPolicyFormUseCase.updatePolicy(any(), any()),
        ).called(1);
      },
    );
  });
}
