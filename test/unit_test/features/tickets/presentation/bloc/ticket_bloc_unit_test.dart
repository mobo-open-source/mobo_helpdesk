import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/rating/domain/usecases/review_usecase.dart';
import 'package:mobo_helpdesk/features/tickets/domain/entities/ticket_entity.dart';
import 'package:mobo_helpdesk/features/tickets/domain/usecases/ticket_form_usecase.dart';
import 'package:mobo_helpdesk/features/tickets/domain/usecases/ticket_list_usecase.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTicketListUseCase extends Mock implements TicketListUseCase {}

class MockTicketFormUseCase extends Mock implements TicketFormUseCase {}

class MockTrackEvent extends Mock implements TrackEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TicketBloc bloc;
  late MockTicketListUseCase mockTicketListUseCase;
  late MockTicketFormUseCase mockTicketFormUseCase;
  late MockTrackEvent mockTrackEvent;

  setUp(() {
    mockTicketListUseCase = MockTicketListUseCase();
    mockTicketFormUseCase = MockTicketFormUseCase();
    mockTrackEvent = MockTrackEvent();
    bloc = TicketBloc(
      mockTicketListUseCase,
      mockTicketFormUseCase,
      mockTrackEvent,
    );
  });

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'serverVersion': '17',
    });
  });

  group('TicketBloc - Load Tickets', () {
    blocTest<TicketBloc, TicketState>(
      'emits loading then success when loadTickets succeeds',
      build: () {
        when(
              () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
            search: any(named: 'search'),
            customDomain: any(named: 'customDomain'),
          ),
        ).thenAnswer((_) async => {
          'data': <TicketEntity>[],
          'total': 0,
        });

        // The list loads its own lookups (stages, users, activity types).
        when(() => mockTicketListUseCase.loadStages())
            .thenAnswer((_) async => [
          {'id': 1, 'name': 'Stage A'}
        ]);
        when(() => mockTicketListUseCase.loadUsers())
            .thenAnswer((_) async => []);
        when(() => mockTicketListUseCase.loadActivityTypes())
            .thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(TicketsLoad(1)),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', true),
        isA<TicketState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isPaginationLoading, 'isPaginationLoading', false)
            .having((s) => s.data, 'data', isEmpty)
            .having((s) => s.total, 'total', 0)
            .having((s) => s.page, 'page', 1)
            .having((s) => s.defaultStage, 'defaultStage', isNotNull),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits API error map directly when loadTickets throws map',
      build: () {
        when(
              () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
            search: any(named: 'search'),
            customDomain: any(named: 'customDomain'),
          ),
        ).thenThrow({
          'title': 'API Error',
          'description': 'Something went wrong',
        });

        return bloc;
      },
      act: (bloc) => bloc.add(TicketsLoad(1)),
      expect: () => [
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', true),
        isA<TicketState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error?['title'], 'title', 'API Error')
            .having(
              (s) => s.error?['description'],
          'description',
          'Something went wrong',
        ),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when loadTickets fails',
      build: () {
        when(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).thenThrow(Exception('Failed to load'));

        return bloc;
      },
      act: (bloc) => bloc.add(TicketsLoad(1)),
      expect: () => [
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', true),
        isA<TicketState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });

  group('TicketBloc - Delete Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'calls deleteTicket and triggers TicketsLoad and emits success message on success',
      build: () {
        when(
          () => mockTicketListUseCase.deleteTicket(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).thenAnswer((_) async => {'data': <TicketEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteTicket(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Ticket deleted successfully')
            .having((s) => s.isError, 'isError', false),
        isA<TicketState>().having((s) => s.message, 'message', null),
        // The reload that follows the action.
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.deleteTicket(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTicketListUseCase.deleteTicket(any()),
        ).thenThrow(Exception('Failed to delete'));
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteTicket(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Failed to delete')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.deleteTicket(1)).called(1);
      },
    );
  });

  group('TicketBloc - Archive Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'calls archiveTicket and triggers TicketsLoad and emits success message on success',
      build: () {
        when(
          () => mockTicketListUseCase.archiveTicket(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).thenAnswer((_) async => {'data': <TicketEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(ArchiveTicket(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Ticket archived successfully')
            .having((s) => s.isError, 'isError', false),
        isA<TicketState>().having((s) => s.message, 'message', null),
        // The reload that follows the action.
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.archiveTicket(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTicketListUseCase.archiveTicket(any()),
        ).thenThrow(Exception('Failed to archive'));
        return bloc;
      },
      act: (bloc) => bloc.add(ArchiveTicket(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Failed to archive')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.archiveTicket(1)).called(1);
      },
    );
  });

  group('TicketBloc - Unarchive Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'calls unArchiveTicket and triggers TicketsLoad and emits success message on success',
      build: () {
        when(
          () => mockTicketListUseCase.unArchiveTicket(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).thenAnswer((_) async => {'data': <TicketEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(UnArchiveTicket(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having(
              (s) => s.message,
              'message',
              'Ticket unarchived successfully',
            )
            .having((s) => s.isError, 'isError', false),
        isA<TicketState>().having((s) => s.message, 'message', null),
        // The reload that follows the action.
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.unArchiveTicket(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
          ),
        ).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTicketListUseCase.unArchiveTicket(any()),
        ).thenThrow(Exception('Failed to unarchive'));
        return bloc;
      },
      act: (bloc) => bloc.add(UnArchiveTicket(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Failed to unarchive')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.unArchiveTicket(1)).called(1);
      },
    );
  });

  group('TicketBloc - Load Selected Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'emits loading then success when all APIs succeed',
      build: () {
        when(() => mockTicketFormUseCase.loadTicketData(any())).thenAnswer(
              (_) async => [
                {
                  'team_id': [1, 'Team A'],
                  'user_id': [2, 'User A'],
                  'ticket_type_id': [3, 'Type A'],
                  'partner_id': [4, 'Customer A'],
                  'stage_id': [5, 'Stage A'],
                  'tag_ids': [10],
                }
          ],
        );

        when(() => mockTicketFormUseCase.loadHelpdeskTeam())
            .thenAnswer((_) async => [{'id': 1, 'name': 'Team A'}]);

        when(() => mockTicketFormUseCase.loadUsers())
            .thenAnswer((_) async => [{'id': 2, 'name': 'User A'}]);

        when(() => mockTicketFormUseCase.loadTypes())
            .thenAnswer((_) async => [{'id': 3, 'name': 'Type A'}]);

        when(() => mockTicketFormUseCase.loadTags())
            .thenAnswer((_) async => [{'id': 10, 'name': 'Tag A'}]);

        when(() => mockTicketFormUseCase.loadPartners())
            .thenAnswer((_) async => [{'id': 4, 'name': 'Customer A'}]);

        when(() => mockTicketFormUseCase.loadStages())
            .thenAnswer((_) async => [{'id': 5, 'name': 'Stage A'}]);

        when(() => mockTicketFormUseCase.loadSalesTeam())
            .thenAnswer((_) async => [{'id': 6, 'name': 'Sales A'}]);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSingleTicket(1)),
      expect: () => [
        isA<TicketState>().having((s) => s.isLoading, 'loading', true),
        isA<TicketState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.selectedTicket, 'ticket', isNotNull)
            .having((s) => s.selectedTeam, 'team', isNotNull)
            .having((s) => s.selectedUser, 'user', isNotNull)
            .having((s) => s.selectedPartner, 'partner', isNotNull)
            .having((s) => s.selectedStage, 'stage', isNotNull)
            .having((s) => s.selectedTags?.length, 'tags length', 1),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'handles empty ticket data safely',
      build: () {
        when(() => mockTicketFormUseCase.loadTicketData(any()))
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadHelpdeskTeam())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadUsers())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadTypes())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadTags())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadPartners())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadStages())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadSalesTeam())
            .thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSingleTicket(1)),
      expect: () => [
        isA<TicketState>().having((s) => s.isLoading, 'loading', true),
        isA<TicketState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.selectedTicket, 'ticket', isNull),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when loadTicketData fails',
      build: () {
        when(() => mockTicketFormUseCase.loadTicketData(any()))
            .thenThrow(Exception('Failed to load'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSingleTicket(1)),
      expect: () => [
        isA<TicketState>().having((s) => s.isLoading, 'loading', true),
        isA<TicketState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.error?['description'],
          'error',
          contains('Failed'),
        ),
      ],
    );
  });

  group('TicketBloc - Clearing a dropdown selection', () {
    const selected = TicketState(
      selectedTeam: {'id': 5, 'name': 'Team'},
      selectedUser: {'id': 6, 'name': 'User'},
      selectedType: {'id': 8, 'name': 'Type'},
      selectedPartner: {'id': 9, 'name': 'Partner'},
      selectedTags: [
        {'id': 100, 'name': 'Tag A'},
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'clears the assignee when its clear button reports null',
      build: () => bloc,
      seed: () => selected,
      act: (bloc) => bloc.add(const UpdateSelectedUser(null)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.selectedUser, 'user', isNull)
            // Only the cleared field changes.
            .having((s) => s.selectedTeam?['id'], 'team', 5)
            .having((s) => s.selectedPartner?['id'], 'partner', 9),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'clears the partner when its clear button reports null',
      build: () => bloc,
      seed: () => selected,
      act: (bloc) => bloc.add(const UpdateSelectedPartner(null)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.selectedPartner, 'partner', isNull)
            .having((s) => s.selectedUser?['id'], 'user', 6),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'clears the type when its clear button reports null',
      build: () => bloc,
      seed: () => selected,
      act: (bloc) => bloc.add(const UpdateSelectedType(null)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.selectedType, 'type', isNull)
            .having((s) => s.selectedUser?['id'], 'user', 6),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'keeps a selection when an unrelated field changes',
      build: () => bloc,
      seed: () => selected,
      act: (bloc) =>
          bloc.add(const UpdateSelectedUser({'id': 11, 'name': 'Other'})),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.selectedUser?['id'], 'user', 11)
            .having((s) => s.selectedTeam?['id'], 'team', 5)
            .having((s) => s.selectedTags?.length, 'tags', 1),
      ],
    );
  });

  group('TicketBloc - Load create data for Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'clears selections left over from a previously opened or created ticket',
      build: () {
        when(() => mockTicketFormUseCase.loadHelpdeskTeam())
            .thenAnswer((_) async => [{'id': 1, 'name': 'Team A'}]);
        when(() => mockTicketFormUseCase.loadUsers())
            .thenAnswer((_) async => [{'id': 10, 'name': 'User A'}]);
        when(() => mockTicketFormUseCase.loadTypes()).thenAnswer((_) async => []);
        when(() => mockTicketFormUseCase.loadTags())
            .thenAnswer((_) async => [{'id': 100, 'name': 'Tag A'}]);
        when(() => mockTicketFormUseCase.loadPartners())
            .thenAnswer((_) async => [{'id': 200, 'name': 'Partner A'}]);
        when(() => mockTicketFormUseCase.loadStages())
            .thenAnswer((_) async => [{'id': 300, 'name': 'Stage A'}]);
        return bloc;
      },
      seed: () => const TicketState(
        selectedTicket: {'id': 7},
        selectedTeam: {'id': 5, 'name': 'Old team'},
        selectedUser: {'id': 6, 'name': 'Old user'},
        selectedType: {'id': 8, 'name': 'Old type'},
        selectedPartner: {'id': 9, 'name': 'Old partner'},
        selectedTags: [
          {'id': 100, 'name': 'Tag A'},
        ],
        selectedStage: {'id': 4, 'name': 'Old stage'},
      ),
      act: (bloc) => bloc.add(LoadTicketCreateData()),
      expect: () => [
        // Cleared straight away, before anything is fetched, so the form never
        // renders the old values while the dropdown data loads.
        isA<TicketState>()
            .having((s) => s.isCreateDataLoading, 'loading', true)
            .having((s) => s.selectedTicket, 'ticket', isNull)
            .having((s) => s.selectedTeam, 'team', isNull)
            .having((s) => s.selectedUser, 'user', isNull)
            .having((s) => s.selectedType, 'type', isNull)
            .having((s) => s.selectedPartner, 'partner', isNull)
            .having((s) => s.selectedTags, 'tags', isNull)
            .having((s) => s.selectedStage, 'stage', isNull),
        // Only the default stage is pre-selected once the data has loaded.
        isA<TicketState>()
            .having((s) => s.isCreateDataLoading, 'loading', false)
            .having((s) => s.selectedTeam, 'team', isNull)
            .having((s) => s.selectedUser, 'user', isNull)
            .having((s) => s.selectedPartner, 'partner', isNull)
            .having((s) => s.selectedTags, 'tags', isNull)
            .having((s) => s.selectedStage?['id'], 'stage', 300),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits loading then success with all data when APIs succeed',
      build: () {
        when(() => mockTicketFormUseCase.loadHelpdeskTeam())
            .thenAnswer((_) async => [{'id': 1, 'name': 'Team A'}]);

        when(() => mockTicketFormUseCase.loadUsers())
            .thenAnswer((_) async => [{'id': 10, 'name': 'User A'}]);

        when(() => mockTicketFormUseCase.loadTypes())
            .thenAnswer((_) async => [{'id': 2, 'name': 'Type A'}]);

        when(() => mockTicketFormUseCase.loadTags())
            .thenAnswer((_) async => [{'id': 100, 'name': 'Tag A'}]);

        when(() => mockTicketFormUseCase.loadPartners())
            .thenAnswer((_) async => [{'id': 200, 'name': 'Partner A'}]);

        when(() => mockTicketFormUseCase.loadStages())
            .thenAnswer((_) async => [{'id': 300, 'name': 'Stage A'}]);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadTicketCreateData()),
      expect: () => [
        isA<TicketState>().having((s) => s.isCreateDataLoading, 'loading', true),
        isA<TicketState>()
            .having((s) => s.isCreateDataLoading, 'loading', false)
            .having((s) => s.helpdeskTeam, 'team', isNotEmpty)
            .having((s) => s.users, 'users', isNotEmpty)
            .having((s) => s.types, 'types', isNotEmpty)
            .having((s) => s.tags, 'tags', isNotEmpty)
            .having((s) => s.partners, 'partners', isNotEmpty)
            .having((s) => s.stages, 'stages', isNotEmpty)
            .having((s) => s.selectedStage, 'selectedStage', isNotNull),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'handles empty stages safely',
      build: () {
        when(() => mockTicketFormUseCase.loadHelpdeskTeam())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadUsers())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadTypes())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadTags())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadPartners())
            .thenAnswer((_) async => []);

        when(() => mockTicketFormUseCase.loadStages())
            .thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadTicketCreateData()),
      expect: () => [
        isA<TicketState>().having((s) => s.isCreateDataLoading, 'loading', true),
        isA<TicketState>()
            .having((s) => s.isCreateDataLoading, 'loading', false)
            .having((s) => s.selectedStage, 'selectedStage', isNull),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits loading false when unexpected error occurs',
      build: () {
        when(() => mockTicketFormUseCase.loadHelpdeskTeam())
            .thenAnswer((_) async => throw Exception('Unexpected'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadTicketCreateData()),
      expect: () => [
        isA<TicketState>().having((s) => s.isCreateDataLoading, 'loading', true),
        isA<TicketState>().having((s) => s.isCreateDataLoading, 'loading', false),
      ],
    );
  });

  group('TicketBloc - Create Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'emits success message when policy create succeed',
      build: () {
        when(
          () => mockTicketFormUseCase.createTicket(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        CreateTicket({
          'name': "Cabinet Colour and Lock aren't proper",
          'description': '''Hi,

          I purchased a "Cabinet With Doors" from your store a few days ago. The lock is not working properly and the color is wrong. This is unacceptable! I am asking for a product that corresponds to my order and that matches the quality you are advertising.

            Regards,
            The Jackson Group''',
          'partner_phone': 123456789,
          'priority': 3,
          'email_cc': 'marc@gmail.com',
          'team_id': 1,
          'user_id': 1,
          'tag_ids': [1, 2, 3],
          'partner_id': 1,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TicketState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Ticket created successfully')
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(() => mockTicketFormUseCase.createTicket(any())).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTicketFormUseCase.createTicket(any()),
        ).thenThrow(Exception('Failed to create'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        CreateTicket({
          'name': "Cabinet Colour and Lock aren't proper",
          'description': '''Hi,

          I purchased a "Cabinet With Doors" from your store a few days ago. The lock is not working properly and the color is wrong. This is unacceptable! I am asking for a product that corresponds to my order and that matches the quality you are advertising.

            Regards,
            The Jackson Group''',
          'partner_phone': 123456789,
          'priority': 3,
          'email_cc': 'marc@gmail.com',
          'team_id': 1,
          'user_id': 1,
          'tag_ids': [1, 2, 3],
          'partner_id': 1,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TicketState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to create')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTicketFormUseCase.createTicket(any())).called(1);
      },
    );
  });

  group('TicketBloc - Update Ticket', () {
    blocTest<TicketBloc, TicketState>(
      'emits success message when policy update succeed',
      build: () {
        when(
          () => mockTicketFormUseCase.updateTicket(any(), any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTicket(1, {
          'name': "Cabinet Colour and Lock aren't proper",
          'description': '''Hi,

          I purchased a "Cabinet With Doors" from your store a few days ago. The lock is not working properly and the color is wrong. This is unacceptable! I am asking for a product that corresponds to my order and that matches the quality you are advertising.

            Regards,
            The Jackson Group''',
          'partner_phone': 123456789,
          'priority': 3,
          'email_cc': 'marc@gmail.com',
          'team_id': 1,
          'user_id': 1,
          'tag_ids': [1, 2, 3],
          'partner_id': 1,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TicketState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Ticket updated successfully')
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(
          () => mockTicketFormUseCase.updateTicket(any(), any()),
        ).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTicketFormUseCase.updateTicket(any(), any()),
        ).thenThrow(Exception('Failed to update'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTicket(1, {
          'name': "Cabinet Colour and Lock aren't proper",
          'description': '''Hi,

          I purchased a "Cabinet With Doors" from your store a few days ago. The lock is not working properly and the color is wrong. This is unacceptable! I am asking for a product that corresponds to my order and that matches the quality you are advertising.

            Regards,
            The Jackson Group''',
          'partner_phone': 123456789,
          'priority': 3,
          'email_cc': 'marc@gmail.com',
          'team_id': 1,
          'user_id': 1,
          'tag_ids': [1, 2, 3],
          'partner_id': 1,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TicketState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to update')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(
          () => mockTicketFormUseCase.updateTicket(any(), any()),
        ).called(1);
      },
    );
  });

  group('TicketBloc - Load Stage Templates', () {
    blocTest<TicketBloc, TicketState>(
      'emits templates when loadStageTemplates succeeds',
      build: () {
        when(() => mockTicketListUseCase.loadEmailTemplate(any()))
            .thenAnswer((_) async => [
          {'id': 1, 'name': 'Email Template A'}
        ]);

        when(() => mockTicketListUseCase.loadSmsTemplate(any()))
            .thenAnswer((_) async => [
          {'id': 2, 'name': 'SMS Template A'}
        ]);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadStageTemplates(1)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.emailTemplates, 'emailTemplates', isNotEmpty)
            .having((s) => s.smsTemplates, 'smsTemplates', isNotEmpty),
      ],
      verify: (_) {
        verify(() => mockTicketListUseCase.loadEmailTemplate(1)).called(1);
        verify(() => mockTicketListUseCase.loadSmsTemplate(1)).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits loading false when email template API fails',
      build: () {
        when(() => mockTicketListUseCase.loadEmailTemplate(any()))
            .thenThrow(Exception('Email failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadStageTemplates(1)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.isLoading, 'loading', false),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits loading false when sms template API fails',
      build: () {
        when(() => mockTicketListUseCase.loadEmailTemplate(any()))
            .thenAnswer((_) async => []);

        when(() => mockTicketListUseCase.loadSmsTemplate(any()))
            .thenThrow(Exception('SMS failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadStageTemplates(1)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.isLoading, 'loading', false),
      ],
    );

    blocTest<TicketBloc, TicketState>(
      'emits empty templates when APIs return empty data',
      build: () {
        when(() => mockTicketListUseCase.loadEmailTemplate(any()))
            .thenAnswer((_) async => []);

        when(() => mockTicketListUseCase.loadSmsTemplate(any()))
            .thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadStageTemplates(1)),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.emailTemplates, 'emailTemplates', isEmpty)
            .having((s) => s.smsTemplates, 'smsTemplates', isEmpty),
      ],
    );
  });

  group('TicketBloc - Update Stage', () {
    blocTest<TicketBloc, TicketState>(
      'update stage success',
      build: () {
        when(
          () => mockTicketListUseCase.updateStage(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
            customDomain: any(named: 'customDomain'),
          ),
        ).thenAnswer((_) async => {'data': <TicketEntity>[], 'total': 0});

        return bloc;
      },
      act: (bloc) => bloc.add(UpdateStage(stageId: 1, newName: 'Archived')),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Stage updated successfully')
            .having((s) => s.isError, 'isError', false),
        isA<TicketState>(),
        // The reload that follows the update.
        isA<TicketState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(
          () => mockTicketListUseCase.updateStage(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).called(1);
        verify(
          () => mockTicketListUseCase.loadTickets(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            search: any(named: 'search'),
            filters: any(named: 'filters'),
            groupBy: any(named: 'groupBy'),
            dateUnit: any(named: 'dateUnit'),
            selectedDates: any(named: 'selectedDates'),
            customDomain: any(named: 'customDomain'),
          ),
        ).called(1);
      },
    );

    blocTest<TicketBloc, TicketState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTicketListUseCase.updateStage(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenThrow(Exception('Failed to update'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateStage(
          stageId: 1,
          newName: 'Archived',
          emailTemplate: 1,
          smsTemplate: 1,
          sequence: 2,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TicketState>()
            .having((s) => s.message, 'message', 'Failed to update')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(
          () => mockTicketListUseCase.updateStage(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).called(1);
      },
    );
  });
}
