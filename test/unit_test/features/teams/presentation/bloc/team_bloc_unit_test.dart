import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/utils/odoo_install_errors.dart';
import 'package:mobo_helpdesk/features/rating/domain/usecases/review_usecase.dart';
import 'package:mobo_helpdesk/features/teams/domain/entities/team_entity.dart';
import 'package:mobo_helpdesk/features/teams/domain/usecases/team_form_usecase.dart';
import 'package:mobo_helpdesk/features/teams/domain/usecases/team_list_usecase.dart';
import 'package:mobo_helpdesk/features/teams/presentation/bloc/team_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockTeamListUseCase extends Mock implements TeamListUseCase {}

class MockTeamFormUseCase extends Mock implements TeamFormUseCase {}

class MockTrackEvent extends Mock implements TrackEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TeamBloc bloc;
  late MockTeamListUseCase mockTeamListUseCase;
  late MockTeamFormUseCase mockTeamFormUseCase;
  late MockTrackEvent mockTrackEvent;

  setUp(() {
    mockTeamListUseCase = MockTeamListUseCase();
    mockTeamFormUseCase = MockTeamFormUseCase();
    mockTrackEvent = MockTrackEvent();
    bloc = TeamBloc(mockTeamListUseCase, mockTeamFormUseCase, mockTrackEvent);
  });

  group('TeamBloc - Load Teams', () {
    blocTest<TeamBloc, TeamState>(
      'emits loading then success when loadTeams succeeds',
      build: () {
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            search: any(named: 'search'),
          ),
        ).thenAnswer((_) async => {'data': <TeamEntity>[], 'total': 0});

        return bloc;
      },
      act: (bloc) => bloc.add(TeamsLoad(1)),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<TeamState>().having((s) => s.isLoading, 'isLoading', true),
        isA<TeamState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isPaginationLoading, 'isPaginationLoading', false)
            .having((s) => s.data, 'data', isEmpty)
            .having((s) => s.total, 'total', 0)
            .having((s) => s.page, 'page', 1),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'emits API error map directly when loadTeams throws map',
      build: () {
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            search: any(named: 'search'),
          ),
        ).thenThrow({
          'title': 'API Error',
          'description': 'Something went wrong',
        });

        return bloc;
      },
      act: (bloc) => bloc.add(TeamsLoad(1)),
      expect: () => [
        isA<TeamState>().having((s) => s.isLoading, 'isLoading', true),
        isA<TeamState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error?['title'], 'title', 'API Error')
            .having(
              (s) => s.error?['description'],
              'description',
              'Something went wrong',
            ),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when loadTeams fails',
      build: () {
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            search: any(named: 'search'),
          ),
        ).thenThrow(Exception('Failed to load'));

        return bloc;
      },
      act: (bloc) => bloc.add(TeamsLoad(1)),
      expect: () => [
        isA<TeamState>().having((s) => s.isLoading, 'isLoading', true),
        isA<TeamState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });

  group('TeamBloc - a pull-to-refresh that fails', () {
    // A refresh of a list already on screen shows no skeleton: it turns the
    // "loading" flag on, and the failure has to turn it off again.
    blocTest<TeamBloc, TeamState>(
      'does not leave the list stuck as still loading',
      build: () {
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
            search: any(named: 'search'),
          ),
        ).thenThrow(Exception('offline'));
        return bloc;
      },
      seed: () => const TeamState(isLoading: false, page: 1, data: []),
      act: (bloc) => bloc.add(const TeamsLoad(1)),
      expect: () => [
        isA<TeamState>().having((s) => s.isPaginationLoading, 'refreshing', true),
        isA<TeamState>()
            .having((s) => s.isPaginationLoading, 'refreshing', false)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });

  group('TeamBloc - Delete Team', () {
    blocTest<TeamBloc, TeamState>(
      'calls deleteTeam and triggers TeamsLoad and emits success message on success',
      build: () {
        when(
          () => mockTeamListUseCase.deleteTeam(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
          ),
        ).thenAnswer((_) async => {'data': <TeamEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteTeam(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Team deleted successfully')
            .having((s) => s.isError, 'isError', false),
        isA<TeamState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockTeamListUseCase.deleteTeam(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
          ),
        ).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamListUseCase.deleteTeam(any()),
        ).thenThrow(Exception('Failed to delete'));
        return bloc;
      },
      act: (bloc) => bloc.add(DeleteTeam(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Failed to delete')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamListUseCase.deleteTeam(1)).called(1);
      },
    );
  });

  group('TeamBloc - Archive Team', () {
    blocTest<TeamBloc, TeamState>(
      'calls archiveTeam and triggers TeamsLoad and emits success message on success',
      build: () {
        when(
          () => mockTeamListUseCase.archiveTeam(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
          ),
        ).thenAnswer((_) async => {'data': <TeamEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(ArchiveTeam(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Team archived successfully')
            .having((s) => s.isError, 'isError', false),
        isA<TeamState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockTeamListUseCase.archiveTeam(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
          ),
        ).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamListUseCase.archiveTeam(any()),
        ).thenThrow(Exception('Failed to archive'));
        return bloc;
      },
      act: (bloc) => bloc.add(ArchiveTeam(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Failed to archive')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamListUseCase.archiveTeam(1)).called(1);
      },
    );
  });

  group('TeamBloc - Unarchive Team', () {
    blocTest<TeamBloc, TeamState>(
      'calls unArchiveTeam and triggers TeamsLoad and emits success message on success',
      build: () {
        when(
          () => mockTeamListUseCase.unArchiveTeam(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        when(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
          ),
        ).thenAnswer((_) async => {'data': <TeamEntity>[], 'total': 0});
        return bloc;
      },
      act: (bloc) => bloc.add(UnarchiveTeam(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Team unarchived successfully')
            .having((s) => s.isError, 'isError', false),
        isA<TeamState>().having((s) => s.message, 'message', null),
      ],
      verify: (_) {
        verify(() => mockTeamListUseCase.unArchiveTeam(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
        verify(
          () => mockTeamListUseCase.loadTeams(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            filters: any(named: 'filters'),
          ),
        ).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamListUseCase.unArchiveTeam(any()),
        ).thenThrow(Exception('Failed to unarchive'));
        return bloc;
      },
      act: (bloc) => bloc.add(UnarchiveTeam(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Failed to unarchive')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamListUseCase.unArchiveTeam(1)).called(1);
      },
    );
  });

  group('TeamBloc - Load Selected team', () {
    blocTest<TeamBloc, TeamState>(
      'emits loading then success when all APIs succeed',
      build: () {
        when(() => mockTeamFormUseCase.loadTeamData(any())).thenAnswer(
          (_) async => [
            {
              'privacy_visibility': 'public',
              'assign_method': 'manual',
              'alias_domain_id': [1, 'Domain A'],
              'alias_contact': 'everyone',
              'website_id': [2, 'Website A'],
              'project_id': [3, 'Project A'],
              'resource_calendar_id': [4, 'Calendar A'],
              'to_stage_id': [5, 'Stage A'],
              'message_partner_ids': [10],
              'member_ids': [20],
              'from_stage_ids': [30],
            },
          ],
        );

        when(() => mockTeamFormUseCase.loadMembers()).thenAnswer(
          (_) async => [
            {'id': 20, 'name': 'Member A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadPartners()).thenAnswer(
          (_) async => [
            {'id': 10, 'name': 'Partner A'},
          ],
        );

        when(
          () => mockTeamFormUseCase.loadWebsite(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadResourceCalendar(any()),
        ).thenAnswer((_) async => []);

        when(() => mockTeamFormUseCase.loadStages()).thenAnswer(
          (_) async => [
            {'id': 30, 'name': 'Stage X'},
          ],
        );

        when(
          () => mockTeamFormUseCase.loadProjects(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadAliasDomain(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.installCheck('website'),
        ).thenAnswer((_) async => true);

        when(
          () => mockTeamFormUseCase.installCheck('project'),
        ).thenAnswer((_) async => true);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSingleTeam(1)),
      expect: () => [
        isA<TeamState>().having((s) => s.isLoading, 'loading', true),
        isA<TeamState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.selectedTeam, 'team', isNotNull)
            .having((s) => s.selectedMembers?.length, 'members', 1)
            .having((s) => s.selectedPartners?.length, 'partners', 1)
            .having((s) => s.selectedInStages?.length, 'stages', 1),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'handles empty team data safely',
      build: () {
        when(
          () => mockTeamFormUseCase.loadTeamData(any()),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadMembers(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadPartners(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadWebsite(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadResourceCalendar(any()),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadStages(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadProjects(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.loadAliasDomain(),
        ).thenAnswer((_) async => []);

        when(
          () => mockTeamFormUseCase.installCheck(any()),
        ).thenAnswer((_) async => false);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSingleTeam(1)),
      expect: () => [
        isA<TeamState>().having((s) => s.isLoading, 'loading', true),
        isA<TeamState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.selectedTeam, 'team', isNull),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when loadTeamData fails',
      build: () {
        when(
          () => mockTeamFormUseCase.loadTeamData(any()),
        ).thenThrow(Exception('Failed to load'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSingleTeam(1)),
      expect: () => [
        isA<TeamState>().having((s) => s.isLoading, 'loading', true),
        isA<TeamState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.error?['description'],
              'error',
              contains('Failed'),
            ),
      ],
    );
  });

  group('TeamBloc - Load create data for Team', () {
    blocTest<TeamBloc, TeamState>(
      'emits loading then success with all data when APIs succeed',
      build: () {
        when(() => mockTeamFormUseCase.loadMembers()).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Member A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadPartners()).thenAnswer(
          (_) async => [
            {'id': 10, 'name': 'Partner A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadWebsite()).thenAnswer(
          (_) async => [
            {'id': 2, 'name': 'Website A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadResourceCalendar(any())).thenAnswer(
          (_) async => [
            {'id': 100, 'name': 'Resource A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadStages()).thenAnswer(
          (_) async => [
            {'id': 100, 'name': 'Stage A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadProjects()).thenAnswer(
          (_) async => [
            {'id': 100, 'name': 'Project A'},
          ],
        );

        when(() => mockTeamFormUseCase.loadAliasDomain()).thenAnswer(
          (_) async => [
            {'id': 100, 'name': 'Domain Alias A'},
          ],
        );

        when(
          () => mockTeamFormUseCase.installCheck('website'),
        ).thenAnswer((_) async => true);

        when(
          () => mockTeamFormUseCase.installCheck('project'),
        ).thenAnswer((_) async => true);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadTeamCreateData()),
      expect: () => [
        isA<TeamState>().having((s) => s.isFormLoading, 'loading', true),
        isA<TeamState>()
            .having((s) => s.isFormLoading, 'loading', false)
            .having((s) => s.members?.length, 'members', 1)
            .having((s) => s.partners?.length, 'partners', 1)
            .having((s) => s.website?.length, 'website', 1)
            .having((s) => s.resources?.length, 'resources', 1)
            .having((s) => s.stages?.length, 'stages', 1)
            .having((s) => s.projects?.length, 'projects', 1)
            .having((s) => s.aliasDomains?.length, 'aliasDomains', 1)
            .having((s) => s.isWebsiteInstalled, 'website installed', true)
            .having((s) => s.isProjectInstalled, 'project installed', true)
            .having((s) => s.selectedVisibility, 'visibility', 'portal')
            .having((s) => s.selectedAssignment, 'assignment', 'balanced')
            .having((s) => s.selectedAliasFrom, 'aliasFrom', 'everyone'),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'emits success with empty lists when all APIs fail',
      build: () {
        when(() => mockTeamFormUseCase.loadMembers()).thenThrow(Exception());

        when(() => mockTeamFormUseCase.loadPartners()).thenThrow(Exception());

        when(() => mockTeamFormUseCase.loadWebsite()).thenThrow(Exception());

        when(
          () => mockTeamFormUseCase.loadResourceCalendar(any()),
        ).thenThrow(Exception());

        when(() => mockTeamFormUseCase.loadStages()).thenThrow(Exception());

        when(() => mockTeamFormUseCase.loadProjects()).thenThrow(Exception());

        when(
          () => mockTeamFormUseCase.loadAliasDomain(),
        ).thenThrow(Exception());

        when(
          () => mockTeamFormUseCase.loadAliasDomain(),
        ).thenThrow(Exception());

        when(
          () => mockTeamFormUseCase.installCheck(any()),
        ).thenAnswer((_) async => false);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadTeamCreateData()),
      expect: () => [
        isA<TeamState>().having((s) => s.isFormLoading, 'loading', true),
        isA<TeamState>()
            .having((s) => s.isFormLoading, 'loading', false)
            .having((s) => s.members ?? [], 'members', isEmpty)
            .having((s) => s.partners ?? [], 'partners', isEmpty)
            .having((s) => s.website ?? [], 'website', isEmpty)
            .having((s) => s.resources ?? [], 'resources', isEmpty)
            .having((s) => s.stages ?? [], 'stages', isEmpty)
            .having((s) => s.projects ?? [], 'projects', isEmpty)
            .having((s) => s.aliasDomains ?? [], 'aliasDomains', isEmpty),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'emits loading false when unexpected error occurs',
      build: () {
        when(
          () => mockTeamFormUseCase.loadMembers(),
        ).thenAnswer((_) async => throw Exception('Unexpected'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadTeamCreateData()),
      expect: () => [
        isA<TeamState>().having((s) => s.isFormLoading, 'loading', true),
        isA<TeamState>().having((s) => s.isFormLoading, 'loading', false),
      ],
    );
  });

  group('TeamBloc - Create Team', () {
    blocTest<TeamBloc, TeamState>(
      'emits success message when policy create succeed',
      build: () {
        when(
          () => mockTeamFormUseCase.createTeam(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        CreateTeam({
          'name': 'Customer Care',
          'description': 'Customer Care Team',
          'alias_name': 'customer-care',
          'auto_close_day': 3,
          'privacy_visibility': 'internal',
          'message_partner_ids': [1, 2, 3],
          'auto_assignment': true,
          'assign_method': 'randomly',
          'member_ids': [1, 2, 3],
          'use_alias': true,
          'alias_domain_id': 1,
          'alias_contact': 'followers',
          'use_website_helpdesk_livechat': true,
          'use_website_helpdesk_form': true,
          'use_website_helpdesk_knowledge': true,
          'use_website_helpdesk_forum': true,
          'use_website_helpdesk_slides': true,
          'use_helpdesk_timesheet': true,
          'website_id': 1,
          'project_id': 1,
          'use_helpdesk_sale_timesheet': true,
          'use_sla': true,
          'resource_calendar_id': 1,
          'use_rating': true,
          'portal_show_rating': true,
          'allow_portal_ticket_closing': true,
          'auto_close_ticket': true,
          'to_stage_id': 1,
          'from_stage_ids': [1, 2, 3],
          'use_credit_notes': true,
          'use_coupons': true,
          'use_product_returns': true,
          'use_product_repairs': true,
          'use_fsm': true,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Team created successfully')
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.createTeam(any())).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamFormUseCase.createTeam(any()),
        ).thenThrow(Exception('Failed to create'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        CreateTeam({
          'name': 'Customer Care',
          'description': 'Customer Care Team',
          'alias_name': 'customer-care',
          'auto_close_day': 3,
          'privacy_visibility': 'internal',
          'message_partner_ids': [1, 2, 3],
          'auto_assignment': true,
          'assign_method': 'randomly',
          'member_ids': [1, 2, 3],
          'use_alias': true,
          'alias_domain_id': 1,
          'alias_contact': 'followers',
          'use_website_helpdesk_livechat': true,
          'use_website_helpdesk_form': true,
          'use_website_helpdesk_knowledge': true,
          'use_website_helpdesk_forum': true,
          'use_website_helpdesk_slides': true,
          'use_helpdesk_timesheet': true,
          'website_id': 1,
          'project_id': 1,
          'use_helpdesk_sale_timesheet': true,
          'use_sla': true,
          'resource_calendar_id': 1,
          'use_rating': true,
          'portal_show_rating': true,
          'allow_portal_ticket_closing': true,
          'auto_close_ticket': true,
          'to_stage_id': 1,
          'from_stage_ids': [1, 2, 3],
          'use_credit_notes': true,
          'use_coupons': true,
          'use_product_returns': true,
          'use_product_repairs': true,
          'use_fsm': true,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to create')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.createTeam(any())).called(1);
      },
    );
  });

  group('TeamBloc - save that installs apps', () {
    setUp(() {
      // No real waiting between looks at the server.
      TeamBloc.installPollInterval = Duration.zero;
      when(() => mockTrackEvent()).thenAnswer((_) async => true);
    });
    tearDown(() => TeamBloc.installPollInterval = const Duration(seconds: 3));

    blocTest<TeamBloc, TeamState>(
      'create: shows that apps are installing, then the result',
      build: () {
        when(() => mockTeamFormUseCase.isServerBusyInstalling())
            .thenAnswer((_) async => false);
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenAnswer((_) async {});
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) => bloc.add(
        const CreateTeam({'name': 'Support', 'use_helpdesk_timesheet': true},
            installs: true),
      ),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.savingMessage, 'message', 'Installing apps')
            .having((s) => s.savingHint, 'hint', contains('Keep the app open')),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.savingMessage, 'message cleared', '')
            .having((s) => s.message, 'message',
                'Team created and apps installed successfully')
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) =>
          verify(() => mockTeamFormUseCase.createTeam(any())).called(1),
    );

    blocTest<TeamBloc, TeamState>(
      'a plain save does not look at the server or say "installing"',
      build: () {
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenAnswer((_) async {});
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) => bloc.add(const CreateTeam({'name': 'Support'})),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.savingMessage, 'message', ''),
        isA<TeamState>()
            .having((s) => s.message, 'message', 'Team created successfully'),
      ],
      verify: (_) =>
          verifyNever(() => mockTeamFormUseCase.isServerBusyInstalling()),
    );

    blocTest<TeamBloc, TeamState>(
      'create: waits while another installation is running, then saves',
      build: () {
        var looks = 0;
        // busy twice, then free
        when(() => mockTeamFormUseCase.isServerBusyInstalling())
            .thenAnswer((_) async => ++looks <= 2);
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenAnswer((_) async {});
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) => bloc.add(
        const CreateTeam({'name': 'Support'}, installs: true),
      ),
      expect: () => [
        isA<TeamState>()
            .having((s) => s.savingMessage, 'message', 'Installing apps'),
        isA<TeamState>()
            .having((s) => s.savingMessage, 'message', 'Waiting for the server')
            .having((s) => s.savingHint, 'hint', contains('still running')),
        isA<TeamState>()
            .having((s) => s.savingMessage, 'message', 'Installing apps'),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.isServerBusyInstalling()).called(3);
        verify(() => mockTeamFormUseCase.createTeam(any())).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'create: nothing is saved before the server is free',
      build: () {
        var looks = 0;
        final order = <String>[];
        when(() => mockTeamFormUseCase.isServerBusyInstalling())
            .thenAnswer((_) async {
          order.add('look');
          return ++looks < 2;
        });
        when(() => mockTeamFormUseCase.createTeam(any())).thenAnswer((_) async {
          expect(order, ['look', 'look'], reason: 'saved before the server was free');
        });
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) => bloc.add(const CreateTeam({'name': 'Support'}, installs: true)),
      verify: (_) =>
          verify(() => mockTeamFormUseCase.createTeam(any())).called(1),
    );

    blocTest<TeamBloc, TeamState>(
      'update: the same, with its own wording',
      build: () {
        when(() => mockTeamFormUseCase.isServerBusyInstalling())
            .thenAnswer((_) async => false);
        when(() => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs')))
            .thenAnswer((_) async {});
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) =>
          bloc.add(const UpdateTeam(7, {'use_fsm': true}, installs: true)),
      expect: () => [
        isA<TeamState>().having((s) => s.savingMessage, 'message', 'Installing apps'),
        isA<TeamState>().having((s) => s.message, 'message',
            'Team updated and apps installed successfully'),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'a failed install clears the installing screen and reports the error',
      build: () {
        when(() => mockTeamFormUseCase.isServerBusyInstalling())
            .thenAnswer((_) async => false);
        when(() => mockTeamFormUseCase.createTeam(any())).thenThrow(
          'The server is still starting up or reloading after an installation.',
        );
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) =>
          bloc.add(const CreateTeam({'name': 'Support'}, installs: true)),
      expect: () => [
        isA<TeamState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.savingMessage, 'message cleared', '')
            .having((s) => s.savingHint, 'hint cleared', '')
            .having((s) => s.isError, 'isError', true)
            .having((s) => s.message, 'message', contains('still starting up')),
      ],
    );
  });

  group('TeamBloc - a save that installs apps ends in an error', () {
    // Odoo saves the team, then installs its apps. When the install fails or
    // the connection drops, the team is on the server although the app was
    // told the save failed: the app must look, not just show the error.
    setUp(() {
      TeamBloc.installPollInterval = Duration.zero;
      when(() => mockTrackEvent()).thenAnswer((_) async => true);
      when(() => mockTeamFormUseCase.isServerBusyInstalling())
          .thenAnswer((_) async => false);
    });
    tearDown(() => TeamBloc.installPollInterval = const Duration(seconds: 3));

    const live = {'name': 'Support', 'use_website_helpdesk_livechat': true};

    /// What the server holds for teams called "Support": none before the save,
    /// [after] once it has failed.
    void serverHolds(List<int> after) {
      var asked = 0;
      when(() => mockTeamFormUseCase.teamIdsNamed('Support'))
          .thenAnswer((_) async => ++asked == 1 ? <int>[] : after);
    }

    blocTest<TeamBloc, TeamState>(
      'create: the team is there but its app is not: kept, and said so',
      build: () {
        serverHolds([7]);
        when(() => mockTeamFormUseCase.createTeam(any())).thenThrow(
          "[Errno 2] No such file or directory: '/odoo/mail/odoobot.png'",
        );
        when(() => mockTeamFormUseCase.optionsNeedingInstall(any()))
            .thenAnswer((_) async => ['use_website_helpdesk_livechat']);
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const CreateTeam(live, installs: true)),
      expect: () => [
        isA<TeamState>().having((s) => s.savingMessage, 'message', 'Installing apps'),
        isA<TeamState>().having(
          (s) => s.savingMessage,
          'checking',
          'Checking what the server saved',
        ),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.serverSaved, 'serverSaved', true)
            .having((s) => s.isError, 'isError', true)
            .having((s) => s.message, 'message', contains('"Support" was created'))
            .having((s) => s.message, 'message', contains('odoobot.png'))
            .having((s) => s.message, 'message', contains('switch them off')),
      ],
    );

    blocTest<TeamBloc, TeamState>(
      'create: the team is there and its app got installed: a success',
      build: () {
        serverHolds([7]);
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenThrow(const OdooConnectionLost('connection lost'));
        when(() => mockTeamFormUseCase.optionsNeedingInstall(any()))
            .thenAnswer((_) async => []);
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const CreateTeam(live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.isError, isFalse);
        expect(bloc.state.isSaving, isFalse);
        expect(bloc.state.serverSaved, isFalse);
        expect(bloc.state.message, 'Team created and apps installed successfully');
      },
    );

    blocTest<TeamBloc, TeamState>(
      'create: nothing was saved: the original error, and the form can retry',
      build: () {
        serverHolds([]); // still no team of that name
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenThrow('Alias is already in use');
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const CreateTeam(live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.isError, isTrue);
        expect(bloc.state.serverSaved, isFalse);
        expect(bloc.state.message, 'Alias is already in use');
        verifyNever(() => mockTeamFormUseCase.optionsNeedingInstall(any()));
      },
    );

    blocTest<TeamBloc, TeamState>(
      'create: a team that already had this name is not mistaken for the new one',
      build: () {
        // 5 existed before; the failed save added nothing
        var asked = 0;
        when(() => mockTeamFormUseCase.teamIdsNamed('Support'))
            .thenAnswer((_) async => ++asked >= 1 ? [5] : <int>[]);
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenThrow('Something failed');
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const CreateTeam(live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.serverSaved, isFalse);
        expect(bloc.state.message, 'Something failed');
      },
    );

    blocTest<TeamBloc, TeamState>(
      'create: connection lost: waits for the server before looking, says why',
      build: () {
        serverHolds([7]);
        var looks = 0;
        // busy at the first look (the wait before sending) and twice more
        // after the connection dropped, then free
        when(() => mockTeamFormUseCase.isServerBusyInstalling())
            .thenAnswer((_) async => ++looks != 1 && looks <= 3);
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenThrow(const OdooConnectionLost('connection lost'));
        when(() => mockTeamFormUseCase.optionsNeedingInstall(any()))
            .thenAnswer((_) async => ['use_website_helpdesk_livechat']);
        return bloc;
      },
      wait: const Duration(milliseconds: 120),
      act: (bloc) => bloc.add(const CreateTeam(live, installs: true)),
      verify: (bloc) {
        verify(() => mockTeamFormUseCase.isServerBusyInstalling()).called(4);
        expect(bloc.state.serverSaved, isTrue);
        expect(bloc.state.message, contains('connection to the server dropped'));
      },
    );

    blocTest<TeamBloc, TeamState>(
      'create: the server cannot be asked afterwards: the original error stands',
      build: () {
        var asked = 0;
        when(() => mockTeamFormUseCase.teamIdsNamed('Support')).thenAnswer((_) async {
          if (++asked == 1) return <int>[];
          throw Exception('offline');
        });
        when(() => mockTeamFormUseCase.createTeam(any()))
            .thenThrow('Could not create the team');
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const CreateTeam(live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.isError, isTrue);
        expect(bloc.state.serverSaved, isFalse);
        expect(bloc.state.message, 'Could not create the team');
      },
    );

    blocTest<TeamBloc, TeamState>(
      'a save that installs nothing is not second-guessed',
      build: () {
        when(() => mockTeamFormUseCase.createTeam(any())).thenThrow('Boom');
        return bloc;
      },
      wait: const Duration(milliseconds: 60),
      act: (bloc) => bloc.add(const CreateTeam({'name': 'Support'})),
      verify: (bloc) {
        verifyNever(() => mockTeamFormUseCase.teamIdsNamed(any()));
        expect(bloc.state.message, 'Boom');
      },
    );

    blocTest<TeamBloc, TeamState>(
      'update: the server holds the edits but not the app: kept, and said so',
      build: () {
        when(() => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs')))
            .thenThrow('The server could not finish the installation');
        when(() => mockTeamFormUseCase.holdsSave(7, any()))
            .thenAnswer((_) async => true);
        when(() => mockTeamFormUseCase.optionsNeedingInstall(any()))
            .thenAnswer((_) async => ['use_website_helpdesk_livechat']);
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const UpdateTeam(7, live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.serverSaved, isTrue);
        expect(bloc.state.isError, isTrue);
        expect(bloc.state.message, contains('Your changes were saved'));
        expect(bloc.state.message, contains('could not finish the installation'));
      },
    );

    blocTest<TeamBloc, TeamState>(
      'update: the app got installed after all: a success',
      build: () {
        when(() => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs')))
            .thenThrow(const OdooConnectionLost('connection lost'));
        when(() => mockTeamFormUseCase.holdsSave(7, any()))
            .thenAnswer((_) async => true);
        when(() => mockTeamFormUseCase.optionsNeedingInstall(any()))
            .thenAnswer((_) async => []);
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const UpdateTeam(7, live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.isError, isFalse);
        expect(bloc.state.message, 'Team updated and apps installed successfully');
      },
    );

    blocTest<TeamBloc, TeamState>(
      'update: the server holds none of the edits: the original error',
      build: () {
        when(() => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs')))
            .thenThrow('Alias is already in use');
        when(() => mockTeamFormUseCase.holdsSave(7, any()))
            .thenAnswer((_) async => false);
        return bloc;
      },
      wait: const Duration(milliseconds: 80),
      act: (bloc) => bloc.add(const UpdateTeam(7, live, installs: true)),
      verify: (bloc) {
        expect(bloc.state.serverSaved, isFalse);
        expect(bloc.state.message, 'Alias is already in use');
      },
    );
  });

  group('TeamBloc - Update Team', () {
    blocTest<TeamBloc, TeamState>(
      'emits success message when policy update succeed',
      build: () {
        when(
          () => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs')),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTeam(1, {
          'name': 'Customer Care',
          'description': 'Customer Care Team',
          'alias_name': 'customer-care',
          'auto_close_day': 3,
          'privacy_visibility': 'internal',
          'message_partner_ids': [1, 2, 3],
          'auto_assignment': true,
          'assign_method': 'randomly',
          'member_ids': [1, 2, 3],
          'use_alias': true,
          'alias_domain_id': 1,
          'alias_contact': 'followers',
          'use_website_helpdesk_livechat': true,
          'use_website_helpdesk_form': true,
          'use_website_helpdesk_knowledge': true,
          'use_website_helpdesk_forum': true,
          'use_website_helpdesk_slides': true,
          'use_helpdesk_timesheet': true,
          'website_id': 1,
          'project_id': 1,
          'use_helpdesk_sale_timesheet': true,
          'use_sla': true,
          'resource_calendar_id': 1,
          'use_rating': true,
          'portal_show_rating': true,
          'allow_portal_ticket_closing': true,
          'auto_close_ticket': true,
          'to_stage_id': 1,
          'from_stage_ids': [1, 2, 3],
          'use_credit_notes': true,
          'use_coupons': true,
          'use_product_returns': true,
          'use_product_repairs': true,
          'use_fsm': true,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Team updated successfully')
            .having((s) => s.isError, 'isError', false),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs'))).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs')),
        ).thenThrow(Exception('Failed to update'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateTeam(1, {
          'name': 'Customer Care',
          'description': 'Customer Care Team',
          'alias_name': 'customer-care',
          'auto_close_day': 3,
          'privacy_visibility': 'internal',
          'message_partner_ids': [1, 2, 3],
          'auto_assignment': true,
          'assign_method': 'randomly',
          'member_ids': [1, 2, 3],
          'use_alias': true,
          'alias_domain_id': 1,
          'alias_contact': 'followers',
          'use_website_helpdesk_livechat': true,
          'use_website_helpdesk_form': true,
          'use_website_helpdesk_knowledge': true,
          'use_website_helpdesk_forum': true,
          'use_website_helpdesk_slides': true,
          'use_helpdesk_timesheet': true,
          'website_id': 1,
          'project_id': 1,
          'use_helpdesk_sale_timesheet': true,
          'use_sla': true,
          'resource_calendar_id': 1,
          'use_rating': true,
          'portal_show_rating': true,
          'allow_portal_ticket_closing': true,
          'auto_close_ticket': true,
          'to_stage_id': 1,
          'from_stage_ids': [1, 2, 3],
          'use_credit_notes': true,
          'use_coupons': true,
          'use_product_returns': true,
          'use_product_repairs': true,
          'use_fsm': true,
        }),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having((s) => s.isSaving, 'isSaving', true),
        isA<TeamState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to update')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.updateTeam(any(), any(), installs: any(named: 'installs'))).called(1);
      },
    );
  });

  group('TeamBloc - Install Website', () {
    blocTest<TeamBloc, TeamState>(
      'emits success message when website installed successfully',
      build: () {
        when(
          () => mockTeamFormUseCase.loadWebsiteModules(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(LoadInstallWebsite(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having(
          (s) => s.isModuleInstallLoading,
          'isModuleInstallLoading',
          true,
        ),

        isA<TeamState>()
            .having(
              (s) => s.message,
              'message',
              'Website Installed Successfully',
            )
            .having((s) => s.isError, 'isError', false)
            .having((s) => s.isError, 'isModuleInstallLoading', false),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.loadWebsiteModules(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamFormUseCase.loadWebsiteModules(any()),
        ).thenThrow(Exception('Failed to install'));
        return bloc;
      },
      act: (bloc) => bloc.add(LoadInstallWebsite(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having(
          (s) => s.isModuleInstallLoading,
          'isModuleInstallLoading',
          true,
        ),

        isA<TeamState>()
            .having((s) => s.message, 'message', 'Failed to install')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.loadWebsiteModules(1)).called(1);
      },
    );
  });

  group('TeamBloc - Install Project', () {
    blocTest<TeamBloc, TeamState>(
      'emits success message when project installed successfully',
      build: () {
        when(
          () => mockTeamFormUseCase.loadProjectModules(any()),
        ).thenAnswer((_) async => true);
        when(() => mockTrackEvent()).thenAnswer((_) async => true);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadInstallProject(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having(
          (s) => s.isModuleInstallLoading,
          'isModuleInstallLoading',
          true,
        ),

        isA<TeamState>()
            .having(
              (s) => s.message,
              'message',
              'Project installed successfully',
            )
            .having((s) => s.isError, 'isError', false)
            .having((s) => s.isError, 'isModuleInstallLoading', false),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.loadProjectModules(1)).called(1);
        verify(() => mockTrackEvent()).called(1);
      },
    );

    blocTest<TeamBloc, TeamState>(
      'emits error when exception occurs',
      build: () {
        when(
          () => mockTeamFormUseCase.loadProjectModules(any()),
        ).thenThrow(Exception('Failed to install'));
        return bloc;
      },
      act: (bloc) => bloc.add(LoadInstallProject(1)),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<TeamState>().having(
          (s) => s.isModuleInstallLoading,
          'isModuleInstallLoading',
          true,
        ),

        isA<TeamState>()
            .having((s) => s.message, 'message', 'Failed to install')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockTeamFormUseCase.loadProjectModules(1)).called(1);
      },
    );
  });
}
