import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/core/widgets/auto_hide_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/empty_lottie.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';
import 'package:mobo_helpdesk/features/teams/presentation/pages/team_form.dart';

import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/custom_list_tile.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/filter_group_widget.dart';
import '../../../../core/widgets/list_kanban_header_widget.dart';
import '../../../../core/widgets/list_view_shimmer.dart';
import '../../../../core/widgets/show_rating.dart';
import '../../../../di/injection_container.dart';
import '../bloc/team_bloc.dart';

/// Displays a paginated list of teams with search, filter, and CRUD actions.
///
/// Features:
/// - Fetches teams via [TeamBloc]
/// - Supports pagination (next/previous)
/// - Real-time search with debounce
/// - Filter panel (archive, etc.)
/// - Create / Edit / Delete / Archive / Unarchive actions
/// - Pull-to-refresh support
/// - Navigation to [TeamForm] for create/edit
///
/// Uses BlocBuilder and BlocListener to manage UI state updates
/// based on [TeamState].
class TeamList extends StatefulWidget {
  const TeamList({super.key});

  @override
  State<TeamList> createState() => _TeamListState();
}

class _TeamListState extends State<TeamList> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Reloads the list from the server, keeping the filters and the search, and
  /// keeps the spinner up until that has really finished (not for a fixed
  /// moment, which let it vanish before a slow server had answered).
  Future<void> _onRefresh() async {
    final bloc = context.read<TeamBloc>();
    bloc.add(const TeamsLoad(1, filters: null, showSkeleton: true));

    await bloc.stream
        .firstWhere((s) => !s.isLoading && !s.isPaginationLoading)
        .timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<TeamBloc, TeamState>(
      listenWhen: (prev, curr) => prev.message != curr.message,
      listener: (context, state) {
        if (state.message != null) {
          if (state.isError) {
            CustomSnackBar.showError(context, state.message!);
          } else {
            CustomSnackBar.showSuccess(context, state.message!);
            Future.delayed(const Duration(seconds: 3), () {
              if (!context.mounted) return;
              checkRating(context);
            });
          }
        }
      },
      child: Scaffold(
        body: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            if (state.isLoading) {
              return Column(
                children: [
                  // Same spacing as the loaded screen, so nothing shifts.
                  const SizedBox(height: 10),
                  ListKanbanHeaderWidget(
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    selectedFilters: state.selectedFilters,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        context.read<TeamBloc>().add(TeamSearch(value));
                      });
                    },
                    isPaginationLoading: state.isPaginationLoading,
                    currentPageCount: '0',
                    totalCount: '0',
                    displayedCount: 0,
                    currentPage: 0,
                    title: "name",
                  ),
                  const SizedBox(height: 10),
                  const Expanded(child: ListViewShimmer()),
                ],
              );
            }

            if (state.error != null) {
              final error = state.error!;

              return ErrorLottie(
                title: error['title'] ?? 'Error',
                subTitle: error['description'] ?? 'Something went wrong.',
                onPressed: () async {
                  AppBootstrapper.reloadAppBlocs(context);
                  await context.read<CompanyProvider>().initialize();
                },
              );
            }

            if (state.data == null || state.data!.isEmpty) {
              return Column(
                children: [
                  ListKanbanHeaderWidget(
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    isPaginationLoading: state.isPaginationLoading,
                    selectedFilters: state.selectedFilters,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        context.read<TeamBloc>().add(TeamSearch(value));
                      });
                    },
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) {
                          List<String> tempFilters = List.from(
                            state.selectedFilters,
                          );

                          final Map<String, Map<String, String>>
                          filterTechnicalNames = {
                            "Active": {"Archive": "archive"},
                          };

                          final Map<String, Map<String, dynamic>>
                          groupTechnicalNames = {};

                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              return FilterGroupWidget(
                                title: "teams",
                                onClear: () {
                                  setDialogState(() {
                                    tempFilters.clear();
                                  });
                                  _searchController.clear();
                                  context.read<TeamBloc>().add(
                                    const TeamClearFilters(),
                                  );
                                  Navigator.pop(context);
                                },
                                onSubmit: () {
                                  Navigator.pop(context);
                                  context.read<TeamBloc>().add(
                                    TeamsLoad(
                                      1,
                                      filters: tempFilters,
                                      showSkeleton: true,
                                    ),
                                  );
                                },
                                tempFilters: tempFilters,
                                setDialogState: setDialogState,
                                filterMap: filterTechnicalNames,
                                groupMap: groupTechnicalNames,
                                onGroupByChanged: (val) {},

                                onDateUnitChanged: (val) {},
                              );
                            },
                          );
                        },
                      );
                    },
                    currentPageCount: '0',
                    totalCount: '0',
                    displayedCount: 0,
                    currentPage: 0,
                    title: "name",
                  ),
                  Expanded(
                    // An empty list can be pulled down too: a team the server
                    // has but the app does not show yet is found this way.
                    child: RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.primary,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      child: EmptyLottie(
                        physics: const AlwaysScrollableScrollPhysics(),
                        centered: true,
                        title: "No Teams found",
                        isCondition: state.selectedFilters.isNotEmpty == true,
                        subTitle: "Try adjusting your filter'",
                        onPressed: () {
                          _searchController.clear();
                          context.read<TeamBloc>().add(
                            const TeamClearFilters(),
                          );
                        },
                        onRetry: () {
                          context.read<TeamBloc>().add(
                            TeamsLoad(
                              1,
                              filters: state.selectedFilters,
                              showSkeleton: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            final page = state.page;
            const limit = 40;
            final total = state.total;

            final teams = state.data ?? [];

            final start = teams.isEmpty ? 0 : ((page - 1) * limit) + 1;
            final end = (start + teams.length - 1);

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: AutoHideHeader(
                header: Column(
                  children: [
                    SizedBox(height: 10),
                    ListKanbanHeaderWidget(
                      isSearchLoading: state.isSearchLoading,
                      isPaginationLoading: state.isPaginationLoading,
                      selectedFilters: state.selectedFilters,
                      onNext: () {
                        if (!state.isPaginationLoading && end < total) {
                          context.read<TeamBloc>().add(TeamsLoad(page + 1));
                        }
                      },
                      onPrevious: () {
                        if (!state.isPaginationLoading && page > 0) {
                          context.read<TeamBloc>().add(TeamsLoad(page - 1));
                        }
                      },
                      controller: _searchController,
                      onChanged: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();

                        _debounce = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            context.read<TeamBloc>().add(TeamSearch(value));
                          },
                        );
                      },
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            List<String> tempFilters = List.from(
                              state.selectedFilters,
                            );

                            final Map<String, Map<String, String>>
                            filterTechnicalNames = {
                              "Teams": {"Archive": "archive"},
                            };

                            final Map<String, Map<String, dynamic>>
                            groupTechnicalNames = {};

                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return FilterGroupWidget(
                                  title: "teams",
                                  onClear: () {
                                    setDialogState(() {
                                      tempFilters.clear();
                                    });
                                  },
                                  onSubmit: () {
                                    Navigator.pop(context);
                                    context.read<TeamBloc>().add(
                                      TeamsLoad(
                                        1,
                                        filters: tempFilters,
                                        showSkeleton: true,
                                      ),
                                    );
                                  },
                                  tempFilters: tempFilters,
                                  setDialogState: setDialogState,
                                  filterMap: filterTechnicalNames,
                                  groupMap: groupTechnicalNames,
                                  onGroupByChanged: (val) {},

                                  onDateUnitChanged: (val) {},
                                );
                              },
                            );
                          },
                        );
                      },
                      currentPageCount: "$start-$end",
                      totalCount: total.toString(),
                      displayedCount: end,
                      currentPage: page,
                      title: "name",
                    ),
                    SizedBox(height: 10),
                  ],
                ),
                body: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    final isArchiveView = state.selectedFilters.contains(
                      "archive",
                    );

                    return CustomListTile(
                      isArchiveView: isArchiveView,
                      title: "Team",
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BlocProvider(
                              create: (context) =>
                                  sl<TeamBloc>()..add(LoadSingleTeam(team.id)),
                              child: TeamForm(teamId: team.id),
                            ),
                          ),
                        );
                        if (result == true) {
                          if (!context.mounted) return;
                          context.read<TeamBloc>().add(
                            const TeamsLoad(1, showSkeleton: true),
                          );
                        }
                      },
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirm = await ConfirmationDialogWidget.show(
                            context: context,
                            title: 'Delete team',
                            subTitle:
                                'Are you sure you want to delete this team?',
                            negativeButtonText: 'Cancel',
                            positiveButtonText: 'Delete',
                          );

                          if (confirm == true) {
                            if (!context.mounted) return;
                            context.read<TeamBloc>().add(DeleteTeam(team.id));
                          }
                        } else if (value == 'archive') {
                          final confirm = await ConfirmationDialogWidget.show(
                            context: context,
                            title: 'Archive team',
                            subTitle:
                                'Are you sure you want to archive this team?',
                            negativeButtonText: 'Cancel',
                            positiveButtonText: 'Archive',
                          );

                          if (confirm == true) {
                            if (!context.mounted) return;
                            context.read<TeamBloc>().add(ArchiveTeam(team.id));
                          }
                        } else if (value == 'unarchive') {
                          final confirm = await ConfirmationDialogWidget.show(
                            context: context,
                            title: 'Unarchive Team',
                            subTitle:
                                'Are you sure you want to unarchive this team?',
                            negativeButtonText: 'Cancel',
                            positiveButtonText: 'Unarchive',
                          );

                          if (confirm == true) {
                            if (!context.mounted) return;
                            context.read<TeamBloc>().add(
                              UnarchiveTeam(team.id),
                            );
                          }
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            team.companyId['name'],
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (team.emailAlias.isNotEmpty) ...[
                            Text(
                              team.emailAlias,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          if (team.emailAliasName.isNotEmpty) ...[
                            Text(
                              team.emailAliasName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        floatingActionButton: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            if (state.isLoading || state.error != null) {
              return const SizedBox.shrink();
            }
            return FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => sl<TeamBloc>()
                        ..add(
                          LoadTeamCreateData(
                            companyId: context
                                .read<CompanyProvider>()
                                .selectedCompanyId,
                          ),
                        ),

                      child: TeamForm(isCreate: true),
                    ),
                  ),
                );
                if (result == true) {
                  if (!context.mounted) return;
                  context.read<TeamBloc>().add(
                    const TeamsLoad(1, showSkeleton: true),
                  );
                }
              },
              backgroundColor: AppColors.primary,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}
