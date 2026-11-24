import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/widgets/status_bullet.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/custom_list_tile.dart';
import '../../../../core/widgets/group_summary_bar.dart';
import '../../../../core/widgets/list_group_widgets.dart';
import '../../../../core/widgets/priority_stars_widget.dart';
import '../../../../di/injection_container.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../pages/ticket_form.dart';
import 'activity_widget.dart';

/// Builds a list-based ticket view with optional grouping support.
///
/// This widget renders a scrollable list of tickets. It supports both:
/// - Flat list mode (no grouping)
/// - Grouped list mode (based on selected grouping field in state)
///
/// Each ticket is displayed using a [CustomListTile] with actions such as:
/// - View ticket details
/// - Delete ticket
/// - Archive / Unarchive ticket
///
/// When grouping is enabled, tickets are grouped under collapsible
/// [ListGroupWidgets] sections.
///
/// The UI also displays:
/// - Ticket name
/// - Partner and user information
/// - SLA deadline
/// - Activity names
/// - Stage name
/// - Priority indicator
/// - Kanban state indicator using [StatusBullet]
///
/// Navigation:
/// Tapping a ticket opens [TicketForm] using a page transition.
/// On returning with `true`, the ticket list is refreshed.
///
/// Actions:
/// - delete: shows confirmation dialog and deletes ticket
/// - archive: archives ticket after confirmation
/// - unarchive: restores archived ticket after confirmation
///
/// Parameters:
/// - [context]: Build context used for theming and navigation.
/// - [state]: Current [TicketState] from BLoC (contains filters, grouping, etc.).
/// - [tickets]: List of tickets to display.
/// - [groupedList]: Optional grouped structure of tickets.
/// - [isSmartView]: Optional flag to enable smart view mode in ticket form.
///
/// Returns:
/// A [Widget] representing either grouped or flat ticket list view.
Widget buildListView(
  BuildContext context,
  TicketState state,
  List<TicketEntity> tickets,
  List<Map<String, dynamic>>? groupedList,
  bool? isSmartView,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: groupedList != null ? groupedList.length + 1 : tickets.length,
    itemBuilder: (context, rawIndex) {
      var index = rawIndex;
      if (groupedList != null) {
        if (rawIndex == 0) {
          return GroupSummaryBar(
            groupCount: groupedList.length,
            allExpanded: groupedList.every(
              (g) => state.groupExpanded[g["group"] as String] ?? true,
            ),
            onToggleAll: (expand) => context.read<TicketBloc>().add(
              ToggleAllGroups(
                groupedList.map((g) => g["group"] as String).toList(),
                expand,
              ),
            ),
          );
        }
        index = rawIndex - 1;
        final group = groupedList[index];
        final groupName = group["group"] as String;
        final groupItems = group["tickets"] as List<TicketEntity>;
        final expanded = state.groupExpanded[groupName] ?? true;
        final String groupBy = state.selectedGroupBy ?? 'stage';
        return ListGroupWidgets(
          groupName: groupName,
          groupBy: groupBy,
          description:
              '${groupItems.length} ticket${groupItems.length != 1 ? 's' : ''}',
          onTap: () =>
              context.read<TicketBloc>().add(ToggleGroupExpansion(groupName)),
          expanded: expanded,
          child: Column(
            children: groupItems.map((ticket) {
              final isArchiveView = state.selectedFilters.contains("archive");

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CustomListTile(
                  isArchiveView: isArchiveView,
                  title: "Ticket",
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) =>
                              sl<TicketBloc>()
                                ..add(LoadSingleTicket(ticket.id)),
                          child: TicketForm(
                            ticketId: ticket.id,
                            isSmartView: isSmartView,
                          ),
                        ),
                      ),
                    );
                    if (result == true) {
                      if (!context.mounted) return;

                      context.read<TicketBloc>().add(
                        const TicketsLoad(1, showSkeleton: true),
                      );
                    }
                  },
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await ConfirmationDialogWidget.show(
                        context: context,
                        title: 'Delete ticket',
                        subTitle:
                            'Are you sure you want to delete this ticket?',
                        negativeButtonText: 'Cancel',
                        positiveButtonText: 'Delete',
                      );

                      if (confirm == true) {
                        if (!context.mounted) return;
                        context.read<TicketBloc>().add(DeleteTicket(ticket.id));
                      }
                    } else if (value == 'archive') {
                      final confirm = await ConfirmationDialogWidget.show(
                        context: context,
                        title: 'Archive ticket',
                        subTitle:
                            'Are you sure you want to archive this ticket?',
                        negativeButtonText: 'Cancel',
                        positiveButtonText: 'Archive',
                      );
                      if (confirm == true) {
                        if (!context.mounted) return;
                        context.read<TicketBloc>().add(
                          ArchiveTicket(ticket.id),
                        );
                      }
                    } else if (value == 'unarchive') {
                      final confirm = await ConfirmationDialogWidget.show(
                        context: context,
                        title: 'Unarchive Ticket',
                        subTitle:
                            'Are you sure you want to unarchive this ticket?',
                        negativeButtonText: 'Cancel',
                        positiveButtonText: 'Unarchive',
                      );

                      if (confirm == true) {
                        if (!context.mounted) return;

                        context.read<TicketBloc>().add(
                          UnArchiveTicket(ticket.id),
                        );
                      }
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ticket.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      if ((ticket.partner['name'] ?? '').isNotEmpty)
                        Text(
                          ticket.partner['name'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),

                      if ((ticket.user['name'] ?? '').isNotEmpty)
                        Text(
                          ticket.user['name'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),

                      if (ticket.slaDeadline.isNotEmpty)
                        Text(
                          ticket.slaDeadline,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ActivityChipsRow(activities: ticket.activities),

                      if ((ticket.stage['name'] ?? '').isNotEmpty)
                        Text(
                          ticket.stage['name'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),

                      PriorityStarsWidget(priority: ticket.priority),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
      final ticket = tickets[index];
      final isArchiveView = state.selectedFilters.contains("archive");

      return CustomListTile(
        isArchiveView: isArchiveView,
        title: "Ticket",
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider(
                create: (context) =>
                    sl<TicketBloc>()..add(LoadSingleTicket(ticket.id)),
                child: TicketForm(
                  ticketId: ticket.id,
                  isSmartView: isSmartView,
                ),
              ),
            ),
          );
          if (result == true) {
            if (!context.mounted) return;

            context.read<TicketBloc>().add(
              const TicketsLoad(1, showSkeleton: true),
            );
          }
        },
        onSelected: (value) async {
          if (value == 'delete') {
            final confirm = await ConfirmationDialogWidget.show(
              context: context,
              title: 'Delete ticket',
              subTitle: 'Are you sure you want to delete this ticket?',
              negativeButtonText: 'Cancel',
              positiveButtonText: 'Delete',
            );

            if (confirm == true) {
              if (!context.mounted) return;

              context.read<TicketBloc>().add(DeleteTicket(ticket.id));
            }
          } else if (value == 'archive') {
            final confirm = await ConfirmationDialogWidget.show(
              context: context,
              title: 'Archive ticket',
              subTitle: 'Are you sure you want to archive this ticket?',
              negativeButtonText: 'Cancel',
              positiveButtonText: 'Archive',
            );

            if (confirm == true) {
              if (!context.mounted) return;

              context.read<TicketBloc>().add(ArchiveTicket(ticket.id));
            }
          } else if (value == 'unarchive') {
            final confirm = await ConfirmationDialogWidget.show(
              context: context,
              title: 'Unarchive Ticket',
              subTitle: 'Are you sure you want to unarchive this ticket?',
              negativeButtonText: 'Cancel',
              positiveButtonText: 'Unarchive',
            );

            if (confirm == true) {
              if (!context.mounted) return;

              context.read<TicketBloc>().add(UnArchiveTicket(ticket.id));
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 5),
            if ((ticket.partner['name'] ?? '').isNotEmpty) ...[
              Text(
                ticket.partner['name'],
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
            ],
            if ((ticket.user['name'] ?? '').isNotEmpty) ...[
              Text(
                ticket.user['name'],
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
            ],
            if (ticket.slaDeadline.isNotEmpty) ...[
              Text(
                ticket.slaDeadline,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
            ],
            ActivityChipsRow(activities: ticket.activities),
            if ((ticket.stage['name'] ?? '').isNotEmpty) ...[
              Text(
                ticket.stage['name'],
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
            ],
            PriorityStarsWidget(priority: ticket.priority),
          ],
        ),
      );
      // }
    },
  );
}
