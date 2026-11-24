import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/core/widgets/auto_hide_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/empty_lottie.dart';
import 'package:mobo_helpdesk/core/widgets/list_group_widgets.dart';
import '../../../../core/widgets/group_summary_bar.dart';
import 'package:mobo_helpdesk/features/sla_policy/presentation/pages/sla_policy_form.dart';

import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/custom_list_tile.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/filter_group_widget.dart';
import '../../../../core/widgets/list_kanban_header_widget.dart';
import '../../../../core/widgets/list_view_shimmer.dart';
import '../../../../core/widgets/priority_stars_widget.dart';
import '../../../../core/widgets/show_rating.dart';
import '../../../../core/widgets/snackbar.dart';
import '../../../../di/injection_container.dart';
import '../../domain/entities/sla_policy_entity.dart';
import '../bloc/sla_policy_bloc.dart';
import '../widgets/group_items.dart';

/// A screen that displays a paginated and filterable list of SLA policies.
///
/// This screen supports:
/// - Listing SLA policies in both grouped and ungrouped views
/// - Searching policies with debounce support
/// - Filtering and grouping via a bottom sheet
/// - Pagination (next/previous page navigation)
/// - Pull-to-refresh functionality
/// - Archive, unarchive, and delete actions
///
/// It also supports:
/// - Smart view mode (embedded usage without FAB/app bar)
/// - Custom domain filtering for contextual listings
/// - Navigation to SLA policy detail and create/edit form screens
class SlaPolicyList extends StatefulWidget {
  final bool? isSmartView;
  final List<dynamic>? customDomain;
  final SlaPolicyBloc? bloc;

  const SlaPolicyList({
    super.key,
    this.isSmartView,
    this.customDomain,
    this.bloc,
  });

  @override
  State<SlaPolicyList> createState() => _SlaPolicyListState();
}

class _SlaPolicyListState extends State<SlaPolicyList> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late final SlaPolicyBloc _slaBloc;

  @override
  void initState() {
    super.initState();
    _slaBloc = widget.bloc ?? context.read<SlaPolicyBloc>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Groups SLA policies based on the selected grouping field.
  ///
  /// Currently supports:
  /// - helpdesk_team: Groups policies by assigned helpdesk team name
  /// - default: Places policies into a fallback group
  ///
  /// Returns a list of maps containing:
  /// - "group": Group name
  /// - "policies": List of policies in that group
  List<Map<String, dynamic>> _groupSlaPolicy(
    List<SlaPolicyEntity> policies,
    String groupBy,
    SlaPolicyState state,
  ) {
    final Map<String, List<SlaPolicyEntity>> grouped = {};

    for (var policy in policies) {
      String key = "Others";

      switch (groupBy) {
        case 'helpdesk_team':
          key = safeGroupValue(policy.team['name']);
          break;

        default:
          key = "None";
      }

      grouped.putIfAbsent(key, () => []).add(policy);
    }

    return grouped.entries.map((e) {
      return {"group": e.key, "policies": e.value};
    }).toList();
  }

  Future<void> _onRefresh() async {
    _slaBloc.add(
      SlaPolicyLoad(
        1,
        filters: null,
        resetGroupBy: true,
        customDomain: widget.customDomain,
        showSkeleton: true,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSmartView = widget.isSmartView ?? false;

    return BlocListener<SlaPolicyBloc, SlaPolicyState>(
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
        appBar: isSmartView == true
            ? AppBarWidget(
                title: "SLA Policies",
                isDark: isDark,
                onBack: () async {
                  Navigator.pop(context);
                },
              )
            : null,
        body: BlocBuilder<SlaPolicyBloc, SlaPolicyState>(
          builder: (context, state) {
            if (state.isLoading) {
              return Column(
                children: [
                  // Same spacing as the loaded screen, so nothing shifts.
                  const SizedBox(height: 10),
                  ListKanbanHeaderWidget(
                    isSmartView: isSmartView,
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    selectedFilters: state.selectedFilters,
                    selectedGroupBy: state.selectedGroupBy,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _slaBloc.add(
                          SlaPolicySearch(value, widget.customDomain),
                        );
                      });
                    },
                    isPaginationLoading: state.isPaginationLoading,
                    currentPageCount: '0',
                    totalCount: '0',
                    displayedCount: 0,
                    currentPage: 0,
                    title: "name, stage and team",
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
                    isSmartView: isSmartView,
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    isPaginationLoading: state.isPaginationLoading,
                    selectedFilters: state.selectedFilters,
                    selectedGroupBy: state.selectedGroupBy,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _slaBloc.add(
                          SlaPolicySearch(value, widget.customDomain),
                        );
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
                          String? tempGroupBy = state.selectedGroupBy;

                          final Map<String, Map<String, String>>
                          filterTechnicalNames = {
                            "Active": {"Archive": "archive"},
                          };

                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              return FilterGroupWidget(
                                title: "sla policies",
                                onClear: () {
                                  setDialogState(() {
                                    tempFilters.clear();
                                    tempGroupBy = null;
                                  });
                                  _searchController.clear();
                                  _slaBloc.add(
                                    SlaPolicyClearFilters(widget.customDomain),
                                  );
                                  Navigator.pop(context);
                                },
                                onSubmit: () {
                                  Navigator.pop(context);

                                  _slaBloc.add(
                                    SlaPolicyLoad(
                                      1,
                                      filters: tempFilters,
                                      resetGroupBy: tempGroupBy == null,
                                      groupBy: tempGroupBy,
                                      customDomain: widget.customDomain,
                                      showSkeleton: true,
                                    ),
                                  );
                                },
                                tempFilters: tempFilters,
                                tempGroupBy: tempGroupBy,
                                setDialogState: setDialogState,
                                filterMap: filterTechnicalNames,
                                groupMap: groupSlaPolicyTechnicalNames,
                                onGroupByChanged: (val) {
                                  setDialogState(() {
                                    tempGroupBy = val;
                                  });
                                },

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
                    title: "name, stage and team",
                  ),
                  Expanded(
                    child: EmptyLottie(
                      centered: true,
                      title: "No SLA policies found",
                      isCondition: state.selectedFilters.isNotEmpty == true,
                      subTitle: "Try adjusting your filter'",
                      onPressed: () {
                        _searchController.clear();
                        _slaBloc.add(
                          SlaPolicyClearFilters(widget.customDomain),
                        );
                      },
                      onRetry: () {
                        _slaBloc.add(
                          SlaPolicyLoad(
                            1,
                            filters: state.selectedFilters,
                            groupBy: state.selectedGroupBy,
                            customDomain: widget.customDomain,
                            showSkeleton: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            final page = state.page;
            const limit = 40;
            final total = state.total;

            final policies = state.data ?? [];

            final start = policies.isEmpty ? 0 : ((page - 1) * limit) + 1;
            final end = (start + policies.length - 1);

            final bool isGrouped = (state.selectedGroupBy ?? '').isNotEmpty;

            final groupedList = isGrouped
                ? _groupSlaPolicy(policies, state.selectedGroupBy!, state)
                : null;

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: AutoHideHeader(
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    ListKanbanHeaderWidget(
                      isSmartView: isSmartView,
                      isSearchLoading: state.isSearchLoading,
                      isPaginationLoading: state.isPaginationLoading,
                      selectedFilters: state.selectedFilters,
                      selectedGroupBy: state.selectedGroupBy,
                      onNext: () {
                        if (!state.isPaginationLoading && end < total) {
                          _slaBloc.add(
                            SlaPolicyLoad(
                              page + 1,
                              filters: state.selectedFilters,
                              groupBy: state.selectedGroupBy,
                              customDomain: widget.customDomain,
                            ),
                          );
                        }
                      },
                      onPrevious: () {
                        if (!state.isPaginationLoading && page > 0) {
                          _slaBloc.add(
                            SlaPolicyLoad(
                              page - 1,
                              filters: state.selectedFilters,
                              groupBy: state.selectedGroupBy,
                              customDomain: widget.customDomain,
                            ),
                          );
                        }
                      },
                      controller: _searchController,
                      onChanged: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();

                        _debounce = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            _slaBloc.add(
                              SlaPolicySearch(value, widget.customDomain),
                            );
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
                            String? tempGroupBy = state.selectedGroupBy;

                            final Map<String, Map<String, String>>
                            filterTechnicalNames = {
                              "Active": {"Archive": "archive"},
                            };

                            final Map<String, Map<String, dynamic>>
                            groupTechnicalNames = {
                              "None": {
                                "value": null,
                                "description": "No grouping applied",
                              },

                              "Helpdesk Team": {
                                "value": "helpdesk_team",
                                "description":
                                    "SLA policies grouped by helpdesk team",
                              },
                            };

                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return FilterGroupWidget(
                                  title: "sla policies",
                                  onClear: () {
                                    setDialogState(() {
                                      tempFilters.clear();
                                      tempGroupBy = null;
                                    });
                                    _searchController.clear();
                                    _slaBloc.add(
                                      SlaPolicyClearFilters(
                                        widget.customDomain,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  },
                                  onSubmit: () {
                                    Navigator.pop(context);

                                    _slaBloc.add(
                                      SlaPolicyLoad(
                                        1,
                                        filters: tempFilters,
                                        resetGroupBy: tempGroupBy == null,
                                        groupBy: tempGroupBy,
                                        customDomain: widget.customDomain,
                                        showSkeleton: true,
                                      ),
                                    );
                                  },
                                  tempFilters: tempFilters,
                                  tempGroupBy: tempGroupBy,
                                  setDialogState: setDialogState,
                                  filterMap: filterTechnicalNames,
                                  groupMap: groupTechnicalNames,
                                  onGroupByChanged: (val) {
                                    setDialogState(() {
                                      tempGroupBy = val;
                                    });
                                  },

                                  onDateUnitChanged: (val) {},
                                );
                              },
                            );
                          },
                        );
                      },
                      groupCount: groupedList?.length,
                      currentPageCount: "$start-$end",
                      totalCount: total.toString(),
                      displayedCount: end,
                      currentPage: page,
                      title: "name, stage and team",
                    ),
                    SizedBox(height: 10),
                  ],
                ),
                body: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupedList != null
                      ? groupedList.length + 1
                      : policies.length,
                  itemBuilder: (context, rawIndex) {
                    var index = rawIndex;
                    if (groupedList != null) {
                      if (rawIndex == 0) {
                        return GroupSummaryBar(
                          groupCount: groupedList.length,
                          allExpanded: groupedList.every(
                            (g) =>
                                state.groupExpanded[g["group"] as String] ??
                                true,
                          ),
                          onToggleAll: (expand) => _slaBloc.add(
                            ToggleAllGroups(
                              groupedList
                                  .map((g) => g["group"] as String)
                                  .toList(),
                              expand,
                            ),
                          ),
                        );
                      }
                      index = rawIndex - 1;
                      final group = groupedList[index];
                      final groupName = group["group"] as String;
                      final groupItems =
                          group["policies"] as List<SlaPolicyEntity>;
                      final expanded = state.groupExpanded[groupName] ?? true;
                      return ListGroupWidgets(
                        groupName: groupName,
                        description:
                            '${groupItems.length} ${groupItems.length != 1 ? 'policies' : 'policy'}',
                        onTap: () =>
                            _slaBloc.add(ToggleGroupExpansion(groupName)),
                        expanded: expanded,
                        child: Column(
                          children: groupItems.map((policy) {
                            final isArchiveView = state.selectedFilters
                                .contains("archive");

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: CustomListTile(
                                isArchiveView: isArchiveView,
                                title: "SLA Policy",
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) => sl<SlaPolicyBloc>()
                                          ..add(LoadSinglePolicy(policy.id)),
                                        child: SlaPolicyForm(
                                          policyId: policy.id,
                                          isSmartView: isSmartView,
                                        ),
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _slaBloc.add(
                                      const SlaPolicyLoad(
                                        1,
                                        showSkeleton: true,
                                      ),
                                    );
                                  }
                                },
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    final confirm =
                                        await ConfirmationDialogWidget.show(
                                          context: context,
                                          title: 'Delete SLA policy',
                                          subTitle:
                                              'Are you sure you want to delete this SLA policy?',
                                          negativeButtonText: 'Cancel',
                                          positiveButtonText: 'Delete',
                                        );

                                    if (confirm == true) {
                                      _slaBloc.add(DeleteSlaPolicy(policy.id));
                                    }
                                  } else if (value == 'archive') {
                                    final confirm =
                                        await ConfirmationDialogWidget.show(
                                          context: context,
                                          title: 'Archive SLA policy',
                                          subTitle:
                                              'Are you sure you want to archive this SLA policy?',
                                          negativeButtonText: 'Cancel',
                                          positiveButtonText: 'Archive',
                                        );
                                    if (confirm == true) {
                                      _slaBloc.add(ArchiveSlaPolicy(policy.id));
                                    }
                                  } else if (value == 'unarchive') {
                                    final confirm =
                                        await ConfirmationDialogWidget.show(
                                          context: context,
                                          title: 'Unarchive SLA policy',
                                          subTitle:
                                              'Are you sure you want to unarchive this SLA policy?',
                                          negativeButtonText: 'Cancel',
                                          positiveButtonText: 'Unarchive',
                                        );

                                    if (confirm == true) {
                                      _slaBloc.add(
                                        UnArchiveSlaPolicy(policy.id),
                                      );
                                    }
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      policy.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 5),

                                    if ((policy.team['name'] ?? '').isNotEmpty)
                                      Text(
                                        policy.team['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),

                                    if ((policy.stages['name'] ?? '')
                                        .isNotEmpty)
                                      Text(
                                        policy.stages['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),

                                    PriorityStarsWidget(
                                      priority: policy.priority,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }
                    final policy = policies[index];
                    final isArchiveView = state.selectedFilters.contains(
                      "archive",
                    );

                    return CustomListTile(
                      isArchiveView: isArchiveView,
                      title: "SLA policy",
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BlocProvider(
                              create: (context) =>
                                  sl<SlaPolicyBloc>()
                                    ..add(LoadSinglePolicy(policy.id)),
                              child: SlaPolicyForm(
                                policyId: policy.id,
                                isSmartView: isSmartView,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          _slaBloc.add(
                            const SlaPolicyLoad(1, showSkeleton: true),
                          );
                        }
                      },
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirm = await ConfirmationDialogWidget.show(
                            context: context,
                            title: 'Delete SLA policy',
                            subTitle:
                                'Are you sure you want to delete this SLA policy?',
                            negativeButtonText: 'Cancel',
                            positiveButtonText: 'Delete',
                          );

                          if (confirm == true) {
                            _slaBloc.add(DeleteSlaPolicy(policy.id));
                          }
                        } else if (value == 'archive') {
                          final confirm = await ConfirmationDialogWidget.show(
                            context: context,
                            title: 'Archive SLA policy',
                            subTitle:
                                'Are you sure you want to archive this SLA policy?',
                            negativeButtonText: 'Cancel',
                            positiveButtonText: 'Archive',
                          );

                          if (confirm == true) {
                            _slaBloc.add(ArchiveSlaPolicy(policy.id));
                          }
                        } else if (value == 'unarchive') {
                          final confirm = await ConfirmationDialogWidget.show(
                            context: context,
                            title: 'Unarchive SLA policy',
                            subTitle:
                                'Are you sure you want to unarchive this SLA policy?',
                            negativeButtonText: 'Cancel',
                            positiveButtonText: 'Unarchive',
                          );

                          if (confirm == true) {
                            _slaBloc.add(UnArchiveSlaPolicy(policy.id));
                          }
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policy.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if ((policy.team['name'] ?? '').isNotEmpty) ...[
                            Text(
                              policy.team['name'],
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          if ((policy.stages['name'] ?? '').isNotEmpty) ...[
                            Text(
                              policy.stages['name'],
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          PriorityStarsWidget(priority: policy.priority),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        floatingActionButton: isSmartView
            ? null
            : BlocBuilder<SlaPolicyBloc, SlaPolicyState>(
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
                            create: (context) =>
                                sl<SlaPolicyBloc>()
                                  ..add(LoadPolicyCreateData()),
                            child: SlaPolicyForm(isCreate: true),
                          ),
                        ),
                      );
                      if (result == true) {
                        _slaBloc.add(
                          const SlaPolicyLoad(1, showSkeleton: true),
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
