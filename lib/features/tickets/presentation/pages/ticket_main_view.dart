import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/core/widgets/auto_hide_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/empty_lottie.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/pages/ticket_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/filter_group_widget.dart';
import '../../../../core/widgets/list_kanban_header_widget.dart';
import '../../../../core/widgets/list_view_shimmer.dart';
import '../../../../core/widgets/show_rating.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/snackbar.dart';
import '../bloc/ticket_bloc.dart';
import '../widgets/group_items.dart';
import '../widgets/group_ticket.dart';
import '../widgets/ticket_kanban_view.dart';
import '../widgets/ticket_list_view.dart';

/// A main view screen for displaying tickets in both **Kanban** and **List** formats.
///
/// This screen supports:
/// - Ticket listing with pagination
/// - Search with debounce
/// - Filtering and grouping
/// - Kanban/List toggle view
/// - Smart view mode (read-only/embedded usage)
/// - Ticket creation navigation
/// - Pull-to-refresh
///
/// It interacts with [TicketBloc] to manage ticket state and API operations.
class TicketMainView extends StatefulWidget {
  final bool? isSmartView;
  final bool? isDashboardOpen;
  final List<dynamic>? customDomain;
  final TicketBloc? bloc;

  const TicketMainView({
    super.key,
    this.isSmartView,
    this.isDashboardOpen,
    this.customDomain,
    this.bloc,
  });

  @override
  State<TicketMainView> createState() => _TicketMainViewState();
}

class _TicketMainViewState extends State<TicketMainView> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, DateTime> tempSelectedDates = {};
  bool isKanbanView = true;
  String? session;
  String? url;
  late final TicketBloc _ticketBloc;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ticketBloc = widget.bloc ?? context.read<TicketBloc>();

    initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Searches as the user types, once they pause, with no confirm button.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _ticketBloc.add(TicketsSearch(value, widget.customDomain));
    });
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      session = prefs.getString('sessionId');
      url = prefs.getString('url');
    });
  }

  /// Refreshes ticket list by triggering a reload event in [TicketBloc].
  ///
  /// Used by [RefreshIndicator].
  Future<void> _onRefresh() async {
    _ticketBloc.add(
      TicketsLoad(
        1,
        filters: null,
        groupBy: null,
        resetGroupBy: true,
        dateUnit: null,
        selectedDates: null,
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
    final bool isDashboardOpen = widget.isDashboardOpen ?? false;

    return BlocListener<TicketBloc, TicketState>(
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
        appBar: (isSmartView == true || isDashboardOpen == true)
            ? AppBarWidget(
                title: "Tickets",
                isDark: isDark,
                onBack: () async {
                  Navigator.pop(context);
                },
              )
            : null,
        body: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            if (state.isLoading) {
              return Column(
                children: [
                  // Same spacing as the loaded screen, so nothing shifts.
                  const SizedBox(height: 10),
                  ListKanbanHeaderWidget(
                    isMoreView: true,
                    isSmartView: isSmartView,
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    selectedFilters: state.selectedFilters,
                    selectedGroupBy: state.selectedGroupBy,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: _onSearchChanged,
                    isPaginationLoading: state.isPaginationLoading,
                    currentPageCount: '0',
                    totalCount: '0',
                    displayedCount: 0,
                    currentPage: 0,
                    title: "name or subject",
                    isKanbanView: isKanbanView,
                    onViewChanged: (value) {
                      setState(() {
                        isKanbanView = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  // The skeleton follows the view the tickets will appear in.
                  Expanded(
                    child: (!isSmartView && isKanbanView)
                        ? const KanbanViewShimmer()
                        : const ListViewShimmer(),
                  ),
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
                    isMoreView: true,
                    isSmartView: isSmartView,
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    isPaginationLoading: state.isPaginationLoading,
                    selectedFilters: state.selectedFilters,
                    selectedGroupBy: state.selectedGroupBy,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: _onSearchChanged,
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
                          String? tempDateUnit = state.selectedDateUnit;

                          final Map<String, Map<String, String>>
                          filterTechnicalNames = {
                            "Tickets": {
                              "My Tickets": "my_tickets",
                              "Followed": "follow",
                              "Unassigned": "un_assign",
                            },
                            "Priority": {
                              "Urgent": "urgent",
                              "High Priority": "high_priority",
                              "Medium Priority": "medium_priority",
                              "Low Priority": "low_priority",
                            },
                            "SLA Status": {
                              "SLA Success": "sla_success",
                              "SLA in Progress": "sla_progress",
                              "SLA Failed": "sla_fail",
                            },
                            "Stages": {
                              "Open": "open_stage",
                              "Closed": "closed_stage",
                              "Closed in Last 7 days": "closed_7_days",
                              "Closed in Last 30 days": "closed_30_days",
                            },
                            "Status": {
                              "Satisfied": "satisfied",
                              "Okay": "okay",
                              "Dissatisfied": "dis_satisfied",
                            },
                            "Active": {"Archive": "archive"},
                            "Date": {"Creation Date": "create_date"},
                          };

                          final Map<String, String> createDateUnits = {
                            "Year": "year",
                            "Quarter": "quarter",
                            "Month": "month",
                            "Week": "week",
                            "Day": "day",
                          };
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              return FilterGroupWidget(
                                title: "tickets",
                                tempSelectedDates: tempSelectedDates,
                                onClear: () {
                                  setDialogState(() {
                                    tempFilters.clear();
                                    tempGroupBy = null;
                                    tempDateUnit = null;
                                    tempSelectedDates.clear();
                                  });
                                  _searchController.clear();
                                  _ticketBloc.add(
                                    TicketsClearFilters(widget.customDomain),
                                  );
                                  Navigator.pop(context);
                                },
                                onSubmit: () {
                                  Navigator.pop(context);
                                  _ticketBloc.add(
                                    TicketsLoad(
                                      1,
                                      filters: tempFilters,
                                      groupBy: tempGroupBy,
                                      resetGroupBy: tempGroupBy == null,
                                      dateUnit: tempDateUnit,
                                      selectedDates: Map.from(
                                        tempSelectedDates,
                                      ),
                                      customDomain: widget.customDomain,
                                      showSkeleton: true,
                                    ),
                                  );
                                },
                                tempFilters: tempFilters,
                                tempGroupBy: tempGroupBy,
                                tempDateUnit: tempDateUnit,
                                setDialogState: setDialogState,
                                filterMap: filterTechnicalNames,
                                groupMap: groupTicketTechnicalNames,
                                dateUnits: createDateUnits,
                                onGroupByChanged: (val) {
                                  tempGroupBy = val;
                                },

                                onDateUnitChanged: (val) {
                                  tempDateUnit = val;
                                },
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
                    title: "name or subject",
                    isKanbanView: isKanbanView,
                    onViewChanged: (value) {
                      setState(() {
                        isKanbanView = value;
                      });
                    },
                  ),
                  Expanded(
                    child: EmptyLottie(
                      centered: true,
                      title: "No tickets found",
                      isCondition: state.selectedFilters.isNotEmpty == true,
                      subTitle: "Try adjusting your filter'",
                      onPressed: () {
                        _searchController.clear();
                        _ticketBloc.add(
                          TicketsClearFilters(widget.customDomain),
                        );
                      },
                      // Reloads as is: filters, grouping, dates and the search
                      // text all stay applied.
                      onRetry: () {
                        _ticketBloc.add(
                          TicketsLoad(
                            1,
                            filters: state.selectedFilters,
                            groupBy: state.selectedGroupBy,
                            dateUnit: state.selectedDateUnit,
                            selectedDates: state.selectedDates,
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

            final tickets = state.data ?? [];

            final start = tickets.isEmpty ? 0 : ((page - 1) * limit) + 1;
            final end = (start + tickets.length - 1);

            final bool isGrouped = (state.selectedGroupBy ?? '').isNotEmpty;

            final groupedList = isGrouped
                ? groupTickets(tickets, state.selectedGroupBy!, state)
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
                      isMoreView: true,
                      isSmartView: isSmartView,
                      isSearchLoading: state.isSearchLoading,
                      isPaginationLoading: state.isPaginationLoading,
                      selectedFilters: state.selectedFilters,
                      selectedGroupBy: state.selectedGroupBy,
                      onNext: () {
                        if (!state.isPaginationLoading && end < total) {
                          _ticketBloc.add(
                            TicketsLoad(
                              page + 1,
                              filters: state.selectedFilters,
                              groupBy: state.selectedGroupBy,
                              dateUnit: state.selectedDateUnit,
                              selectedDates: state.selectedDates,
                              customDomain: widget.customDomain,
                            ),
                          );
                        }
                      },
                      onPrevious: () {
                        if (!state.isPaginationLoading && page > 0) {
                          _ticketBloc.add(
                            TicketsLoad(
                              page - 1,
                              filters: state.selectedFilters,
                              groupBy: state.selectedGroupBy,
                              dateUnit: state.selectedDateUnit,
                              selectedDates: state.selectedDates,
                              customDomain: widget.customDomain,
                            ),
                          );
                        }
                      },
                      controller: _searchController,
                      onChanged: _onSearchChanged,
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
                            String? tempDateUnit = state.selectedDateUnit;

                            final Map<String, Map<String, String>>
                            filterTechnicalNames = {
                              "Tickets": {
                                "My Tickets": "my_tickets",
                                "Followed": "follow",
                                "Unassigned": "un_assign",
                              },
                              "Priority": {
                                "Urgent": "urgent",
                                "High Priority": "high_priority",
                                "Medium Priority": "medium_priority",
                                "Low Priority": "low_priority",
                              },
                              "SLA Status": {
                                "SLA Success": "sla_success",
                                "SLA in Progress": "sla_progress",
                                "SLA Failed": "sla_fail",
                              },
                              "Stages": {
                                "Open": "open_stage",
                                "Closed": "closed_stage",
                                "Closed in Last 7 days": "closed_7_days",
                                "Closed in Last 30 days": "closed_30_days",
                              },
                              "Status": {
                                "Satisfied": "satisfied",
                                "Okay": "okay",
                                "Dissatisfied": "dis_satisfied",
                              },
                              "Active": {"Archive": "archive"},
                              "Date": {"Creation Date": "create_date"},
                            };

                            final Map<String, Map<String, dynamic>>
                            groupTechnicalNames = {
                              "None": {
                                "value": null,
                                "description": "No grouping applied",
                              },

                              "Assigned to": {
                                "value": "assigned",
                                "description":
                                    "Tickets grouped by assigned user",
                              },
                              "Helpdesk Team": {
                                "value": "helpdesk_team",
                                "description":
                                    "Tickets grouped by helpdesk team",
                              },
                              "Stage": {
                                "value": "stage",
                                "description": "Tickets grouped by stage",
                              },
                              "SLA": {
                                "value": "sla",
                                "description": "Grouped based on SLA status",
                              },
                              "Type": {
                                "value": "type",
                                "description": "Grouped by ticket type",
                              },
                              "Tags": {
                                "value": "tags",
                                "description": "Grouped by tags",
                              },
                              "Priority": {
                                "value": "priority",
                                "description": "Grouped by priority level",
                              },
                              "Partner": {
                                "value": "partner",
                                "description": "Grouped by customer/partner",
                              },
                              "Creation Date": {
                                "value": "create_date",
                                "description":
                                    "Grouped by ticket creation date",
                                "hasUnits": true,
                              },
                              "Properties": {
                                "value": "properties",
                                "description":
                                    "Grouped by ticket properties/custom fields",
                              },
                              "SLA Deadline": {
                                "value": "sla_deadline",
                                "description": "Grouped by SLA deadline",
                                "hasUnits": true,
                              },
                            };

                            final Map<String, String> createDateUnits = {
                              "Year": "year",
                              "Quarter": "quarter",
                              "Month": "month",
                              "Week": "week",
                              "Day": "day",
                            };
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return FilterGroupWidget(
                                  title: "tickets",
                                  tempSelectedDates: tempSelectedDates,
                                  onClear: () {
                                    setDialogState(() {
                                      tempFilters.clear();
                                      tempGroupBy = null;
                                      tempDateUnit = null;
                                      tempSelectedDates.clear();
                                    });
                                    _searchController.clear();
                                    _ticketBloc.add(
                                      TicketsClearFilters(widget.customDomain),
                                    );
                                    Navigator.pop(context);
                                  },
                                  onSubmit: () {
                                    Navigator.pop(context);
                                    _ticketBloc.add(
                                      TicketsLoad(
                                        1,
                                        filters: tempFilters,
                                        groupBy: tempGroupBy,
                                        resetGroupBy: tempGroupBy == null,
                                        dateUnit: tempDateUnit,
                                        selectedDates: Map.from(
                                          tempSelectedDates,
                                        ),
                                        customDomain: widget.customDomain,
                                        showSkeleton: true,
                                      ),
                                    );
                                  },
                                  tempFilters: tempFilters,
                                  tempGroupBy: tempGroupBy,
                                  tempDateUnit: tempDateUnit,
                                  setDialogState: setDialogState,
                                  filterMap: filterTechnicalNames,
                                  groupMap: groupTechnicalNames,
                                  dateUnits: createDateUnits,
                                  onGroupByChanged: (val) {
                                    tempGroupBy = val;
                                  },

                                  onDateUnitChanged: (val) {
                                    tempDateUnit = val;
                                  },
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
                      title: "name or subject",
                      isKanbanView: isKanbanView,
                      onViewChanged: (value) {
                        setState(() {
                          isKanbanView = value;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                  ],
                ),
                body: (!isSmartView && isKanbanView)
                    ? buildKanbanView(context, state, tickets, url, session)
                    : buildListView(
                        context,
                        state,
                        tickets,
                        groupedList,
                        isSmartView,
                      ),
              ),
            );
          },
        ),
        floatingActionButton: isSmartView
            ? null
            : BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  if (state.isLoading || state.error != null) {
                    return const SizedBox.shrink();
                  }
                  final fab = FloatingActionButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlocProvider.value(
                            value: context.read<TicketBloc>()
                              ..add(const LoadTicketCreateData()),
                            child: TicketForm(
                              isCreate: true,
                              defaultStage: state.defaultStage,
                            ),
                          ),
                        ),
                      );
                      if (result == true) {
                        _ticketBloc.add(
                          const TicketsLoad(1, showSkeleton: true),
                        );
                      }
                    },
                    backgroundColor: AppColors.primary,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      color: Colors.white,
                    ),
                  );
                  // Pushed pages have no bottom nav bar; lift the button to
                  // where it sits above the bar on the Tickets tab.
                  return isDashboardOpen == true
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: fab,
                        )
                      : fab;
                },
              ),
      ),
    );
  }
}
