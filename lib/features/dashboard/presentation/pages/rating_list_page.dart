import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/empty_lottie.dart';
import 'package:mobo_helpdesk/features/dashboard/domain/entities/rating_entity.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/widgets/rating_group_items.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/pages/ticket_form.dart';

import '../../../../core/widgets/app_bar_widget.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/custom_list_tile.dart';
import '../../../../core/widgets/error_lottie.dart';
import '../../../../core/widgets/filter_group_widget.dart';
import '../../../../core/widgets/list_group_widgets.dart';
import '../../../../core/widgets/group_summary_bar.dart';
import '../../../../core/widgets/list_kanban_header_widget.dart';
import '../../../../core/widgets/list_view_shimmer.dart';
import '../../../../core/widgets/snackbar.dart';
import '../../../../di/injection_container.dart';
import '../../../tickets/presentation/bloc/ticket_bloc.dart';
import '../widgets/group_rating.dart';
import '../widgets/rating_status.dart';

/// A stateful widget that displays a list of customer ratings with advanced filtering,
/// search, grouping, and pagination capabilities.
///
/// This page allows users to:
/// - View all customer ratings for tickets
/// - Search ratings with debounced input
/// - Filter by status, range, date, and custom groups
/// - Group ratings by different criteria (e.g., date, status)
/// - Navigate to the associated ticket details
/// - Delete individual ratings after confirmation
///
/// The page is typically opened from the Dashboard and supports being initialized
/// with an external [DashboardBloc] for better state management in navigation flows.
class RatingListPage extends StatefulWidget {
  final DashboardBloc? bloc;

  const RatingListPage({super.key, this.bloc});

  @override
  State<RatingListPage> createState() => _RatingListPageState();
}

class _RatingListPageState extends State<RatingListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Map<String, DateTime> tempSelectedDates = {};
  late final DashboardBloc _dashboardBloc;

  @override
  void initState() {
    super.initState();
    _dashboardBloc = widget.bloc ?? context.read<DashboardBloc>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Builds the main UI for the ratings list page.
  ///
  /// Uses [BlocListener] to show success/error snackbars when messages are emitted
  /// from the [DashboardBloc].
  ///
  /// Uses [BlocBuilder] to react to different states:
  /// - **Loading**: Shows shimmer effect with header
  /// - **Error**: Displays error illustration with retry option
  /// - **Empty**: Shows empty state with filter option
  /// - **Success**: Renders paginated list with optional grouping
  ///
  /// Features include:
  /// - Kanban-style header with search, filters, and pagination controls
  /// - Support for grouped and flat list views
  /// - Smooth slide transitions when opening ticket details
  /// - Confirmation dialog before deleting a rating
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<DashboardBloc, DashboardState>(
      listenWhen: (prev, curr) => prev.message != curr.message,
      listener: (context, state) {
        if (state.message != null) {
          if (state.isError) {
            CustomSnackBar.showError(context, state.message!);
          } else {
            CustomSnackBar.showSuccess(context, state.message!);
          }
        }
      },
      child: Scaffold(
        appBar: AppBarWidget(
          title: "Customer Rating",
          isDark: isDark,
          onBack: () async {
            Navigator.pop(context);
          },
        ),
        body: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state.isLoading) {
              return Column(
                children: [
                  // Same spacing as the loaded screen, so nothing shifts.
                  const SizedBox(height: 10),
                  ListKanbanHeaderWidget(
                    isMoreView: false,
                    controller: _searchController,
                    isSearchLoading: state.isSearchLoading,
                    selectedFilters: state.selectedFilters,
                    selectedGroupBy: state.selectedGroupBy,
                    onNext: () {},
                    onPrevious: () {},
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _dashboardBloc.add(RatingSearch(value));
                      });
                    },
                    isPaginationLoading: state.isPaginationLoading,
                    currentPageCount: '0',
                    totalCount: '0',
                    displayedCount: 0,
                    currentPage: 0,
                    title: "ticket",
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
                  context.read<DashboardBloc>().add(RatingsLoad(1));
                },
              );
            }
            if (state.ratingData == null || state.ratingData!.isEmpty) {
              return Column(
                children: [
                  ListKanbanHeaderWidget(
                    isMoreView: false,
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
                        _dashboardBloc.add(RatingSearch(value));
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
                          String? tempDateUnit = state.selectedDateUnit;

                          final Map<String, Map<String, String>>
                          filterTechnicalNames = {
                            "Ratings": {"My Ratings": "my_ratings"},
                            "Status": {
                              "Satisfied": "satisfies",
                              "Okay": "okay",
                              "Dissatisfied": "dis_satisfied",
                            },
                            "Range": {
                              "Today": "today",
                              "Last 7 days": "last_7_days",
                              "Last 30 days": "last_30_days",
                            },
                            "Date": {"Submitted on": "submitted_date"},
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
                                  _dashboardBloc.add(RatingClearFilters());
                                  Navigator.pop(context);
                                },
                                onSubmit: () {
                                  Navigator.pop(context);
                                  _dashboardBloc.add(
                                    RatingsLoad(
                                      1,
                                      filters: tempFilters,
                                      groupBy: tempGroupBy,
                                      resetGroupBy: tempGroupBy == null,
                                      dateUnit: tempDateUnit,
                                      selectedDates: Map.from(
                                        tempSelectedDates,
                                      ),
                                      showSkeleton: true,
                                    ),
                                  );
                                },
                                tempFilters: tempFilters,
                                tempGroupBy: tempGroupBy,
                                tempDateUnit: tempDateUnit,
                                setDialogState: setDialogState,
                                filterMap: filterTechnicalNames,
                                groupMap: groupRatingTechnicalNames,
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
                    title: "ratings",
                  ),
                  Expanded(
                    child: EmptyLottie(
                      title: "No Ratings found",
                      isCondition: state.selectedFilters.isNotEmpty == true,
                      subTitle: "Try adjusting your filter'",
                      onPressed: () {
                        _searchController.clear();
                        _dashboardBloc.add(RatingClearFilters());
                      },
                      onRetry: () {
                        _dashboardBloc.add(
                          RatingsLoad(
                            1,
                            filters: state.selectedFilters,
                            groupBy: state.selectedGroupBy,
                            dateUnit: state.selectedDateUnit,
                            selectedDates: state.selectedDates,
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

            final ratings = state.ratingData ?? [];

            final start = ratings.isEmpty ? 0 : ((page - 1) * limit) + 1;
            final end = (start + ratings.length - 1);

            final bool isGrouped = (state.selectedGroupBy ?? '').isNotEmpty;

            final groupedList = isGrouped
                ? groupRating(ratings, state.selectedGroupBy!, state)
                : null;
            return Column(
              children: [
                SizedBox(height: 10),
                ListKanbanHeaderWidget(
                  isMoreView: false,
                  isSearchLoading: state.isSearchLoading,
                  isPaginationLoading: state.isPaginationLoading,
                  selectedFilters: state.selectedFilters,
                  selectedGroupBy: state.selectedGroupBy,
                  onNext: () {
                    if (!state.isPaginationLoading && end < total) {
                      _dashboardBloc.add(
                        RatingsLoad(
                          page + 1,
                          filters: state.selectedFilters,
                          groupBy: state.selectedGroupBy,
                          dateUnit: state.selectedDateUnit,
                          selectedDates: state.selectedDates,
                        ),
                      );
                    }
                  },
                  onPrevious: () {
                    if (!state.isPaginationLoading && page > 0) {
                      _dashboardBloc.add(
                        RatingsLoad(
                          page - 1,
                          filters: state.selectedFilters,
                          groupBy: state.selectedGroupBy,
                          dateUnit: state.selectedDateUnit,
                          selectedDates: state.selectedDates,
                        ),
                      );
                    }
                  },
                  controller: _searchController,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();

                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      _dashboardBloc.add(RatingSearch(value));
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
                        String? tempDateUnit = state.selectedDateUnit;

                        final Map<String, Map<String, String>>
                        filterTechnicalNames = {
                          "Ratings": {"My Ratings": "my_ratings"},
                          "Status": {
                            "Satisfied": "satisfies",
                            "Okay": "okay",
                            "Dissatisfied": "dis_satisfied",
                          },
                          "Range": {
                            "Today": "today",
                            "Last 7 days": "last_7_days",
                            "Last 30 days": "last_30_days",
                          },
                          "Date": {"Submitted on": "submitted_date"},
                        };

                        final Map<String, Map<String, dynamic>>
                        groupTechnicalNames = groupRatingTechnicalNames;

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
                              title: "ratings",
                              tempSelectedDates: tempSelectedDates,
                              onClear: () {
                                setDialogState(() {
                                  tempFilters.clear();
                                  tempGroupBy = null;
                                  tempDateUnit = null;
                                  tempSelectedDates.clear();
                                });

                                _searchController.clear();
                                _dashboardBloc.add(RatingClearFilters());
                                Navigator.pop(context);
                              },
                              onSubmit: () {
                                Navigator.pop(context);
                                _dashboardBloc.add(
                                  RatingsLoad(
                                    1,
                                    filters: tempFilters,
                                    groupBy: tempGroupBy,
                                    resetGroupBy: tempGroupBy == null,
                                    dateUnit: tempDateUnit,
                                    selectedDates: Map.from(tempSelectedDates),
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
                  title: "rating",
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: groupedList != null
                        ? groupedList.length + 1
                        : ratings.length,
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
                            onToggleAll: (expand) => _dashboardBloc.add(
                              ToggleAllRatingGroups(
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
                            group["ratings"] as List<RatingEntity>;
                        final expanded = state.groupExpanded[groupName] ?? true;
                        return ListGroupWidgets(
                          groupName: groupName,
                          description:
                              '${groupItems.length} ${groupItems.length != 1 ? 'ratings' : 'rating'}',
                          onTap: () => _dashboardBloc.add(
                            ToggleRatingGroupExpansion(groupName),
                          ),
                          expanded: expanded,
                          child: Column(
                            children: groupItems.map((rating) {
                              final status = ratingStatusColor(
                                rating.ratingText,
                              );

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: CustomListTile(
                                  title: "Rating",
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BlocProvider(
                                          create: (context) => sl<TicketBloc>()
                                            ..add(
                                              LoadSingleTicket(rating.resId),
                                            ),
                                          child: TicketForm(
                                            ticketId: rating.resId,
                                          ),
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      if (!context.mounted) return;
                                      _dashboardBloc.add(
                                        const RatingsLoad(
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
                                            title: 'Delete rating',
                                            subTitle:
                                                'Are you sure you want to delete this rating?',
                                            negativeButtonText: 'Cancel',
                                            positiveButtonText: 'Delete',
                                          );

                                      if (confirm == true) {
                                        if (!context.mounted) return;
                                        _dashboardBloc.add(
                                          DeleteRating(rating.id),
                                        );
                                      }
                                    }
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              rating.resName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : status.color.withValues(
                                                      alpha: 0.10,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: status.color,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      if (rating.createDate.isNotEmpty) ...[
                                        Text(
                                          rating.createDate,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (rating
                                          .relatedPartnerId
                                          .isNotEmpty) ...[
                                        Text(
                                          rating.relatedPartnerId['name'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (rating.partnerId.isNotEmpty) ...[
                                        Text(
                                          rating.partnerId['name'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],

                                      if (rating.partnerResName.isNotEmpty) ...[
                                        Text(
                                          rating.partnerResName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }
                      final rating = ratings[index];
                      final status = ratingStatusColor(rating.ratingText);

                      return CustomListTile(
                        isArchiveShow: false,
                        title: "Rating",
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlocProvider(
                                create: (context) =>
                                    sl<TicketBloc>()
                                      ..add(LoadSingleTicket(rating.resId)),
                                child: TicketForm(ticketId: rating.resId),
                              ),
                            ),
                          );
                          if (result == true) {
                            if (!context.mounted) return;
                            _dashboardBloc.add(
                              const RatingsLoad(1, showSkeleton: true),
                            );
                          }
                        },
                        onSelected: (value) async {
                          if (value == 'delete') {
                            final confirm = await ConfirmationDialogWidget.show(
                              context: context,
                              title: 'Delete rating',
                              subTitle:
                                  'Are you sure you want to delete this rating?',
                              negativeButtonText: 'Cancel',
                              positiveButtonText: 'Delete',
                            );

                            if (confirm == true) {
                              if (!context.mounted) return;
                              _dashboardBloc.add(DeleteRating(rating.id));
                            }
                          }
                        },
                        child: Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      rating.resName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : status.color.withValues(
                                              alpha: 0.10,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: status.color,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 5),
                              if (rating.createDate.isNotEmpty) ...[
                                Text(
                                  rating.createDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              if (rating.relatedPartnerId.isNotEmpty) ...[
                                Text(
                                  rating.relatedPartnerId['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              if (rating.partnerId.isNotEmpty) ...[
                                Text(
                                  rating.partnerId['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],

                              if (rating.partnerResName.isNotEmpty) ...[
                                Text(
                                  rating.partnerResName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
