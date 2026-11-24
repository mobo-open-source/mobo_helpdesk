import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/core/widgets/error_lottie.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/pages/rating_list_page.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/widgets/custom_dashboard_tile.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/services/app_bootstrapper.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/helpdesk_ribbon.dart';
import '../../../../core/widgets/profile_image.dart';
import '../../../../di/injection_container.dart';
import '../../../main/presentation/bloc/main_layout_bloc.dart';
import '../../../tickets/presentation/bloc/ticket_bloc.dart';
import '../../../tickets/presentation/pages/ticket_main_view.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/dashboard_shimmer_page.dart';
import '../widgets/rating_widget.dart';
import '../widgets/update_target_widget.dart';

/// A stateful widget that displays the main dashboard screen for the helpdesk application.
///
/// The dashboard provides an overview of the user's tickets, performance metrics,
/// team statistics, and allows navigation to detailed ticket and rating views.
/// It supports switching between different time periods ('Today', 'Avg Last 7 days', 'Daily Target')
/// and includes refresh functionality.
///
/// Features:
/// - Overview cards for open tickets, high priority, and urgent tickets
/// - Average open hours and failed tickets breakdown
/// - Performance metrics with dropdown time filter
/// - Team-wise support statistics
/// - Navigation to ticket lists and rating pages with smooth transitions
/// - Target editing capability for daily goals
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedValue = 'Today';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _buildGreetingText(String userName) {
    final name = userName.trim().isEmpty ? 'User' : userName;
    final firstName = name.split(' ').first;
    return '${_getGreeting()} $firstName!';
  }

  Widget _buildGreetingCard(bool isDark) {
    return BlocBuilder<MainLayoutBloc, MainLayoutState>(
      builder: (context, layoutState) {
        final imageBytes = layoutState.profileImage;
        final isSvg = imageBytes != null ? isSvgBytes(imageBytes) : false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildGreetingText(layoutState.userName),
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage Your Helpdesk Operations Efficiently',
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ProfileImage(
                  avatarBytes: imageBytes,
                  isSvg: isSvg,
                  size: 56,
                  isDashboard: true,
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns performance data based on the currently selected time period.
  ///
  /// This method maps the selected filter (`selectedValue`) to relevant
  /// dashboard metrics such as closed tickets, SLA success rate, and average rating.
  ///
  /// Parameters:
  ///   - `dashboard`: The [DashboardModel] containing all performance data.
  ///
  /// Returns:
  ///   A [Map] with keys: `'value'`, `'rate'`, and `'rating'`.
  // Odoo's wording for the rating cell: "/" without a rating, "4.3 / 5" for
  // today, "4.33 %" for the last 7 days and "4.5 / 5" for the daily target.
  String _outOfFiveRating(double rating) =>
      rating > 0 ? '${rating.toStringAsFixed(1)} / 5' : '/';

  String _percentRating(double rating) =>
      rating > 0 ? '${rating.toStringAsFixed(2)} %' : '/';

  String _trimmedRating(double rating) =>
      rating.toString().replaceFirst(RegExp(r'\.0+$'), '');

  Map<String, String> getPerformanceData(dashboard) {
    switch (selectedValue) {
      case 'Avg Last 7 days':
        return {
          'value': dashboard.closedLast7Days.toString(),
          'rate': dashboard.slaTickets7Days == 0
              ? '/ %'
              : "${dashboard.slaSuccess7Days.toStringAsFixed(2)}%",
          'rating': _percentRating(dashboard.avg7DaysRating),
        };

      case 'Today':
        return {
          'value': dashboard.closedTodayTickets.toString(),
          // Odoo shows "/" while no ticket closed in the period had an SLA.
          'rate': dashboard.slaTicketsToday == 0
              ? '/ %'
              : "${dashboard.slaSuccessTodayRate.toStringAsFixed(2)}%",
          'rating': _outOfFiveRating(dashboard.avgTodayRating),
        };

      case 'Daily Target':
        return {
          'value': dashboard.targetClosedTicket.toString(),
          'rate': "${dashboard.targetSuccessRate.toStringAsFixed(2)}%",
          'rating': "${_trimmedRating(dashboard.targetRating)} / 5",
        };

      default:
        return {
          'value': dashboard.closedLast7Days.toString(),
          'rate': dashboard.slaTickets7Days == 0
              ? '/ %'
              : "${dashboard.slaSuccess7Days.toStringAsFixed(2)}%",
          'rating': _percentRating(dashboard.avg7DaysRating),
        };
    }
  }

  /// Builds the main dashboard UI.
  ///
  /// Uses [BlocBuilder] to listen to [DashboardBloc] state changes and renders
  /// different UIs based on loading, error, or success states.
  ///
  /// The UI includes:
  /// - Shimmer loading effect while data is being fetched
  /// - Error screen with retry option
  /// - Main dashboard content with ticket statistics, performance metrics,
  ///   and team information
  ///
  /// Navigation to ticket and rating pages uses custom slide transitions
  /// for better user experience.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.isLoading) {
            return DashboardShimmerPage(
              isDark: Theme.of(context).brightness == Brightness.dark,
            );
          }

          if (state.error != null) {
            final error = state.error!;

            return ErrorLottie(
              title: error['title'] ?? 'Error',
              subTitle:
                  error['description'] ??
                  'Something went wrong. Please try again later',
              onPressed: () async {
                AppBootstrapper.reloadAppBlocs(context);
                await context.read<CompanyProvider>().initialize();
              },
            );
          }

          if (state.dashboard == null || state.dashboard!.isEmpty) {
            return const Center(child: Text("No data available"));
          }

          final dashboard = state.dashboard!.first;
          final teams = dashboard.teams;
          final performance = getPerformanceData(dashboard);
          final bool isDailyTarget = selectedValue == 'Daily Target';

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DashboardBloc>().add(const DashboardLoad());
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreetingCard(isDark),
                        SizedBox(height: 10),
                        CustomDashboardTile.tileStyle(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "My Tickets",
                                style: TextStyle(
                                  fontSize: 17,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomDashboardTile.topCard(
                                      "Tickets Open",
                                      dashboard.ticketCount.toString(),
                                      Icons.trending_up,
                                      Color(0xFF3A6AE0),
                                      Color(0xFF2F5FD0),
                                      Color(0xFF163B97),
                                      Color(0xFF082981),
                                      isDark,
                                      onTap: dashboard.showDemo
                                          ? null
                                          : () {
                                              final defaultFilters = [
                                                'open_stage',
                                                'my_tickets',
                                              ];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => BlocProvider(
                                                    create: (context) =>
                                                        sl<TicketBloc>()..add(
                                                          TicketsLoad(
                                                            1,
                                                            filters:
                                                                defaultFilters,
                                                            groupBy: null,
                                                            dateUnit: null,
                                                            selectedDates: null,
                                                          ),
                                                        ),
                                                    child: TicketMainView(
                                                      isDashboardOpen: true,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CustomDashboardTile.topCard(
                                      "High Priority",
                                      dashboard.highPriority.toString(),
                                      Icons.error_outline,
                                      Color(0xFFFF2D2D),
                                      Color(0xFFD91C1C),
                                      Color(0xFFA31212),
                                      Color(0xFF6E0808),
                                      isDark,
                                      onTap: dashboard.showDemo
                                          ? null
                                          : () {
                                              final defaultFilters = [
                                                'open_stage',
                                                'my_tickets',
                                                'high_priority',
                                              ];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => BlocProvider(
                                                    create: (context) =>
                                                        sl<TicketBloc>()..add(
                                                          TicketsLoad(
                                                            1,
                                                            filters:
                                                                defaultFilters,
                                                            groupBy: null,
                                                            dateUnit: null,
                                                            selectedDates: null,
                                                          ),
                                                        ),
                                                    child: TicketMainView(
                                                      isDashboardOpen: true,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CustomDashboardTile.topCard(
                                      "Urgent",
                                      dashboard.urgent.toString(),
                                      HugeIcons.strokeRoundedFlash,
                                      Color(0xFFFFC300),
                                      Color(0xFFE0AE00),
                                      Color(0xFFB89300),
                                      Color(0xFF8A6F00),
                                      isDark,
                                      onTap: dashboard.showDemo
                                          ? null
                                          : () {
                                              final defaultFilters = [
                                                'open_stage',
                                                'my_tickets',
                                                'urgent',
                                              ];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => BlocProvider(
                                                    create: (context) =>
                                                        sl<TicketBloc>()..add(
                                                          TicketsLoad(
                                                            1,
                                                            filters:
                                                                defaultFilters,
                                                            groupBy: null,
                                                            dateUnit: null,
                                                            selectedDates: null,
                                                          ),
                                                        ),
                                                    child: TicketMainView(
                                                      isDashboardOpen: true,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              CustomDashboardTile.sectionContainer(
                                title: "Failed Tickets",
                                isDark: isDark,
                                children: [
                                  CustomDashboardTile.statCard(
                                    title: "Tickets",
                                    value: dashboard.failedTickets.toString(),
                                    accent: const Color(0xFF6C8AE4),
                                    icon: HugeIcons.strokeRoundedTicket01,
                                    isDark: isDark,
                                    onTap: dashboard.showDemo
                                        ? null
                                        : () {
                                            final defaultFilters = [
                                              'open_stage',
                                              'my_tickets',
                                              'sla_fail',
                                            ];
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                              ),
                                            );
                                          },
                                  ),
                                  CustomDashboardTile.statCard(
                                    title: "High Priority",
                                    value: dashboard.failedLowPriority
                                        .toString(),
                                    accent: AppColors.primary,
                                    icon: HugeIcons.strokeRoundedAlert02,
                                    isDark: isDark,
                                    onTap: dashboard.showDemo
                                        ? null
                                        : () {
                                            final defaultFilters = [
                                              'open_stage',
                                              'my_tickets',
                                              'high_priority',
                                              'sla_fail',
                                            ];
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                              ),
                                            );
                                          },
                                  ),
                                  CustomDashboardTile.statCard(
                                    title: "Urgent",
                                    value: dashboard.failedHighPriority
                                        .toString(),
                                    accent: const Color(0xFFFBB106),
                                    icon: HugeIcons.strokeRoundedFire,
                                    isDark: isDark,
                                    onTap: dashboard.showDemo
                                        ? null
                                        : () {
                                            final defaultFilters = [
                                              'open_stage',
                                              'my_tickets',
                                              'urgent',
                                              'sla_fail',
                                            ];
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                              ),
                                            );
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              CustomDashboardTile.sectionContainer(
                                title: "Avg Open Hours",
                                isDark: isDark,
                                children: [
                                  CustomDashboardTile.activeCard(
                                    "Tickets",
                                    dashboard.avgOpenHours.toString(),
                                    isDark,
                                  ),
                                  CustomDashboardTile.activeCard(
                                    "High Priority",
                                    dashboard.avgLowPriorityHours.toString(),
                                    isDark,
                                  ),
                                  CustomDashboardTile.activeCard(
                                    "Urgent",
                                    dashboard.avgHighPriorityHours.toString(),
                                    isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 25),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'My Performance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),

                              Container(
                                constraints: const BoxConstraints(
                                  minHeight: 35,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton2<String>(
                                    value: selectedValue,
                                    customButton: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            selectedValue,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ],
                                    ),

                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          selectedValue = value;
                                        });
                                      }
                                    },

                                    dropdownStyleData: DropdownStyleData(
                                      maxHeight: 200,
                                      width: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: isDark
                                            ? Colors.grey[900]
                                            : Colors.white,
                                      ),
                                    ),

                                    items:
                                        const [
                                          'Today',
                                          'Avg Last 7 days',
                                          'Daily Target',
                                        ].map((measure) {
                                          return DropdownMenuItem<String>(
                                            value: measure,
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: selectedValue == measure
                                                    ? (isDark
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.08,
                                                                )
                                                          : Colors.grey
                                                                .withValues(
                                                                  alpha: 0.15,
                                                                ))
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                measure,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 18),
                        CustomDashboardTile.performanceContainers(
                          color: AppColors.primary,
                          icon: Icons.description_outlined,
                          title: 'Closed Tickets',
                          subTitle: 'Resolution rate',
                          endTitle: performance['value']!,
                          isDark: isDark,
                          showEditIcon: dashboard.showDemo
                              ? false
                              : isDailyTarget,
                          onEditTap: () {
                            openEditDialog(
                              context: context,
                              title: "Closed Tickets",
                              description:
                                  "Set the number of tickets you aim to resolve daily.",
                              isRate: false,
                              initialValue: performance['value']!,
                              onSave: (value) {
                                context.read<DashboardBloc>().add(
                                  UpdateTargetEvent(
                                    teamId: dashboard.id,
                                    field: 'helpdesk_target_closed',
                                    value: value,
                                  ),
                                );
                              },
                            );
                          },
                          onTap: dashboard.showDemo
                              ? null
                              : selectedValue == 'Daily Target'
                              ? null
                              : () {
                                  List<String> defaultFilters;
                                  List<dynamic> domain = [];
                                  final now = DateTime.now();

                                  final startOfDay = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ).toIso8601String();

                                  final endOfDay = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                  ).toIso8601String();

                                  if (selectedValue == 'Avg Last 7 days') {
                                    defaultFilters = ['my_tickets'];
                                    domain.add([
                                      'close_date',
                                      '>=',
                                      now
                                          .subtract(const Duration(days: 7))
                                          .toIso8601String(),
                                    ]);
                                  } else {
                                    defaultFilters = [
                                      'my_tickets',
                                      'closed_stage',
                                    ];
                                    domain.add([
                                      'close_date',
                                      '>=',
                                      startOfDay,
                                    ]);
                                    domain.add(['close_date', '<=', endOfDay]);
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) =>
                                            sl<TicketBloc>()..add(
                                              TicketsLoad(
                                                1,
                                                filters: defaultFilters,
                                                groupBy: null,
                                                dateUnit: null,
                                                selectedDates: null,
                                                customDomain: domain,
                                              ),
                                            ),
                                        child: TicketMainView(
                                          isDashboardOpen: true,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                        ),
                        CustomDashboardTile.performanceContainers(
                          color: Colors.green,
                          imageAsset: 'assets/reward.png',
                          title: 'SLA Success Rate',
                          subTitle: 'Service quality',
                          endTitle: performance['rate']!,
                          isDark: isDark,
                          showEditIcon: dashboard.showDemo
                              ? false
                              : isDailyTarget,
                          onEditTap: () {
                            openEditDialog(
                              context: context,
                              title: "SLA Success Rate",
                              description:
                                  "Percentage of tickets resolved within SLA without violations.",
                              isRate: true,
                              initialValue: performance['rate']!.replaceAll(
                                '%',
                                '',
                              ),
                              onSave: (value) {
                                context.read<DashboardBloc>().add(
                                  UpdateTargetEvent(
                                    teamId: dashboard.id,
                                    field: 'helpdesk_target_success',
                                    value: value,
                                  ),
                                );
                              },
                            );
                          },
                          onTap: dashboard.showDemo
                              ? null
                              : selectedValue == 'Daily Target'
                              ? null
                              : () {
                                  List<String> defaultFilters;
                                  List<dynamic> domain = [];
                                  final now = DateTime.now();

                                  final startOfDay = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ).toIso8601String();

                                  final endOfDay = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                  ).toIso8601String();

                                  if (selectedValue == 'Avg Last 7 days') {
                                    defaultFilters = ['my_tickets'];
                                    domain.add([
                                      'close_date',
                                      '>=',
                                      now
                                          .subtract(const Duration(days: 7))
                                          .toIso8601String(),
                                    ]);
                                  } else {
                                    defaultFilters = [
                                      'my_tickets',
                                      'closed_stage',
                                      'sla_success',
                                    ];
                                    domain.add([
                                      'close_date',
                                      '>=',
                                      startOfDay,
                                    ]);
                                    domain.add(['close_date', '<=', endOfDay]);
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) =>
                                            sl<TicketBloc>()..add(
                                              TicketsLoad(
                                                1,
                                                filters: defaultFilters,
                                                groupBy: null,
                                                dateUnit: null,
                                                selectedDates: null,
                                                customDomain: domain,
                                              ),
                                            ),
                                        child: TicketMainView(
                                          isDashboardOpen: true,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                        ),
                        CustomDashboardTile.performanceContainers(
                          color: Color(0xFFF48C06),
                          icon: Icons.star_rounded,
                          title: 'Average Rating',
                          subTitle: 'Customer feedback',
                          endTitle: performance['rating']!,
                          isDark: isDark,
                          showEditIcon: dashboard.showDemo
                              ? false
                              : isDailyTarget,
                          onEditTap: () {
                            openEditDialog(
                              context: context,
                              title: "Average Rating",
                              description:
                                  "Target customer satisfaction rating based on feedback.",
                              initialValue: _trimmedRating(
                                dashboard.targetRating,
                              ),
                              isRate: true,
                              onSave: (value) {
                                context.read<DashboardBloc>().add(
                                  UpdateTargetEvent(
                                    teamId: dashboard.id,
                                    field: 'helpdesk_target_rating',
                                    value: value,
                                  ),
                                );
                              },
                            );
                          },
                          onTap: dashboard.showDemo
                              ? null
                              : selectedValue == 'Daily Target'
                              ? null
                              : () {
                                  List<String> defaultFilters;
                                  List<dynamic> domain = [];
                                  final now = DateTime.now();

                                  final startOfDay = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ).toIso8601String();

                                  final endOfDay = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    23,
                                    59,
                                    59,
                                  ).toIso8601String();

                                  if (selectedValue == 'Avg Last 7 days') {
                                    defaultFilters = [
                                      'last_7_days',
                                      'my_ratings',
                                    ];
                                    domain.add([
                                      'create_date',
                                      '>=',
                                      now
                                          .subtract(const Duration(days: 7))
                                          .toIso8601String(),
                                    ]);
                                  } else {
                                    defaultFilters = ['today', 'my_ratings'];
                                    domain.add([
                                      'create_date',
                                      '>=',
                                      startOfDay,
                                    ]);
                                    domain.add(['create_date', '<=', endOfDay]);
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider(
                                        create: (context) =>
                                            sl<DashboardBloc>()..add(
                                              RatingsLoad(
                                                1,
                                                filters: defaultFilters,
                                                groupBy: null,
                                                dateUnit: null,
                                                selectedDates: null,
                                                customDomain: domain,
                                              ),
                                            ),
                                        child: RatingListPage(),
                                      ),
                                    ),
                                  );
                                },
                        ),
                        SizedBox(height: 15),

                        teams.isNotEmpty
                            ? Text(
                                'Support',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              )
                            : SizedBox.shrink(),
                        SizedBox(height: 18),
                        Column(
                          children: teams.map((team) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                              child: CustomDashboardTile.tileStyle(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            team.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
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
                                                : Colors.blue.withValues(
                                                    alpha: 0.10,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            "Support",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.blue,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        CustomDashboardTile.tileTitleText(
                                          title: "Tickets Closed",
                                          isDark: isDark,
                                        ),
                                        SizedBox(width: 10),
                                        CustomDashboardTile.tileValueText(
                                          value: team.ticketClosed.toString(),
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        CustomDashboardTile.tileTitleText(
                                          title: "% Success Rate",
                                          isDark: isDark,
                                        ),
                                        SizedBox(width: 10),
                                        CustomDashboardTile.tileValueText(
                                          value: team.successRate < 0
                                              ? "-"
                                              : "${team.successRate.toStringAsFixed(2)}%",
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        CustomDashboardTile.tileTitleText(
                                          title: "Average Rating",
                                          isDark: isDark,
                                        ),

                                        ratingWidget(
                                          rating: team.ratingAvg
                                              .toStringAsFixed(1),
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Divider(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.grey.shade200,
                                      thickness: 1,
                                      height: 1,
                                    ),
                                    const SizedBox(height: 15),
                                    IntrinsicHeight(
                                      child: Row(
                                        spacing: 8,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: CustomDashboardTile.statCard(
                                              title: "Open",
                                              value: team.openTicketCount
                                                  .toString(),
                                              accent: Colors.blueAccent,
                                              icon: HugeIcons
                                                  .strokeRoundedFolderOpen,
                                              isDark: isDark,
                                              onTap: () {
                                                final defaultFilters = [
                                                  'open_stage',
                                                ];
                                                List<dynamic> domain = [
                                                  ['team_id', '=', team.id],
                                                ];
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                              customDomain:
                                                                  domain,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: CustomDashboardTile.statCard(
                                              title: "Unassigned",
                                              value: team.unassignedTickets
                                                  .toString(),
                                              accent: const Color(0xFF8157D5),
                                              icon: HugeIcons
                                                  .strokeRoundedUserQuestion01,
                                              isDark: isDark,
                                              onTap: () {
                                                final defaultFilters = [
                                                  'un_assign',
                                                ];
                                                List<dynamic> domain = [
                                                  ['team_id', '=', team.id],
                                                ];
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                              customDomain:
                                                                  domain,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: CustomDashboardTile.statCard(
                                              title: "Urgent",
                                              value: team.urgentTicket
                                                  .toString(),
                                              accent: const Color(0xFFFBB106),
                                              icon: HugeIcons.strokeRoundedFire,
                                              isDark: isDark,
                                              onTap: () {
                                                final defaultFilters = [
                                                  'urgent',
                                                ];
                                                List<dynamic> domain = [
                                                  ['team_id', '=', team.id],
                                                ];
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                              customDomain:
                                                                  domain,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: CustomDashboardTile.statCard(
                                              title: "Failed",
                                              value: team.slaFailed.toString(),
                                              accent: AppColors.primary,
                                              icon: HugeIcons
                                                  .strokeRoundedAlertCircle,
                                              isDark: isDark,
                                              onTap: () {
                                                final defaultFilters = [
                                                  'sla_fail',
                                                ];
                                                List<dynamic> domain = [
                                                  ['team_id', '=', team.id],
                                                ];
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => BlocProvider(
                                                      create: (context) =>
                                                          sl<TicketBloc>()..add(
                                                            TicketsLoad(
                                                              1,
                                                              filters:
                                                                  defaultFilters,
                                                              groupBy: null,
                                                              dateUnit: null,
                                                              selectedDates:
                                                                  null,
                                                              customDomain:
                                                                  domain,
                                                            ),
                                                          ),
                                                      child: TicketMainView(
                                                        isDashboardOpen: true,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                isDark: isDark,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (dashboard.showDemo)
                  HelpdeskRibbon(text: "Sample", color: AppColors.primary),
              ],
            ),
          );
        },
      ),
    );
  }
}
