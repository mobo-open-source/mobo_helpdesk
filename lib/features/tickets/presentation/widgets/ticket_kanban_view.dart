import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/widgets/schedule_activity_dialog.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/widgets/stage_update_popup.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/widgets/status_bullet.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/events/profile_refresh_bus.dart';
import '../../../../core/widgets/confirmation_dialog_widget.dart';
import '../../../../core/widgets/custom_kanban_board.dart';
import '../../../../core/widgets/custom_kanban_tile.dart';
import '../../../../core/widgets/priority_stars_widget.dart';
import '../../../../core/widgets/profile_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/tag_chip_widget.dart';
import '../../../../di/injection_container.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../pages/ticket_form.dart';
import 'activity_details_dialog.dart';
import 'activity_widget.dart';
import 'deadline_format.dart';
import 'kanban_column.dart';

/// Builds a Kanban-style ticket board UI.
///
/// This widget renders a draggable Kanban board for tickets, supporting:
/// - Grouping by stage or custom fields (assigned, priority, partner, etc.)
/// - Dynamic column generation based on grouping rules
/// - Ticket rendering with avatars, tags, SLA deadlines, and activities
/// - Ticket actions such as delete, archive, and unarchive
/// - Navigation to ticket details with live refresh support
///
/// Features:
/// - Supports grouped and ungrouped views
/// - Uses [CustomKanbanBoard] for column-based layout
/// - Integrates with [TicketBloc] for state management
/// - Handles user interactions (edit stage, delete, archive)
/// - Displays SLA status, priority, and activity summaries
///
/// Parameters:
/// - [context]: Build context for UI rendering and navigation
/// - [state]: Current [TicketState] containing filters, grouping, and UI state
/// - [tickets]: List of tickets to render in the Kanban board
/// - [url]: Base URL for loading user avatars
/// - [session]: Session cookie for authenticated image requests
///
/// Returns:
/// A fully built Kanban board widget displaying grouped ticket cards.
Widget buildKanbanView(
  BuildContext context,
  TicketState state,
  List<TicketEntity> tickets,
  String? url,
  String? session,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final bool isGrouped = (state.selectedGroupBy ?? '').isNotEmpty;

  final String groupBy = state.selectedGroupBy ?? 'stage';

  // Stage columns carry the real stage ids that tickets are placed by, so they
  // come from buildStages (also ordered by sequence), not from hashed names.
  final List<Map<String, dynamic>> kanbanColumns =
      isGrouped && groupBy != 'stage'
      ? buildGroupedColumns(tickets, groupBy, state)
      : buildStages(tickets);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 0),
    child: Stack(
      children: [
        CustomKanbanBoard<TicketEntity>(
          data: tickets,
          stages: kanbanColumns,
          getStageName: (t) => getStageNameForTicket(t, groupBy, state),
          getStageId: (t) => getStageIdForTicket(t, groupBy, state),

          onReorder: groupBy == 'stage'
              ? (ticket, newStageId, newStageName) {
                  if (ticket.stage['id'] == newStageId) return;
                  context.read<TicketBloc>().add(
                    MoveTicketToStage(
                      ticketId: ticket.id,
                      newStageId: newStageId,
                      newStageName: newStageName,
                    ),
                  );
                }
              : null,
          onReorderInStage: groupBy == 'stage'
              ? (ticket, stageId, newIndex) {
                  context.read<TicketBloc>().add(
                    ReorderTicketInStage(
                      ticketId: ticket.id,
                      stageId: stageId,
                      newIndex: newIndex,
                    ),
                  );
                }
              : null,

          itemBuilder: (ticket) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final stateColor = ticket.kanbanState == 'normal'
                ? Colors.grey
                : ticket.kanbanState == 'blocked'
                ? Colors.red
                : ticket.kanbanState == 'done'
                ? Colors.green
                : Colors.grey;

            final isArchiveView = state.selectedFilters.contains("archive");

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: CustomKanbanTile(
                title: "Ticket",
                isArchiveView: isArchiveView,
                priority: ticket.priority,
                isBottom: true,
                activityWidget: ActivityWidget(
                  icon: ticket.activityTypeIcon,
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ActivityDetailsDialog(
                        ticketName: ticket.name,
                        activities: ticket.activities,
                        ticketId: ticket.id,
                        onSchedule: () async {
                          final result = await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                ScheduleActivityDialog(ticketId: ticket.id),
                          );
                          if (result == true && context.mounted) {
                            Navigator.pop(context);
                            context.read<TicketBloc>().add(
                              const TicketsLoad(1, isActivityLoading: true),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
                bulletWidget: StatusBullet(
                  color: stateColor,
                  message: ticket.kanbanState,
                ),
                userImageWidget: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Builder(
                      builder: (context) {
                        final baseUrl = url ?? '';
                        final userId = ticket.user['id'];
                        final sessionId = session;

                        // Changes when a profile is saved, so an edited photo
                        // is fetched instead of the cached one.
                        final version = ProfileRefreshBus.avatarVersion;

                        final avatarUrl =
                            "$baseUrl/web/image/res.users/$userId/avatar_128"
                            "${version == 0 ? '' : '?unique=$version'}";

                        final fallbackUrl =
                            "$baseUrl/web/image?model=res.users&id=$userId&field=image_128"
                            "${version == 0 ? '' : '&unique=$version'}";

                        Map<String, String>? headers = sessionId != null
                            ? {"Cookie": "session_id=$sessionId"}
                            : null;

                        return Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          headers: headers,

                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;

                            return const SkeletonShimmer(
                              child: SkeletonCircle(size: 24),
                            );
                          },

                          errorBuilder: (context, error, stackTrace) {
                            return Image.network(
                              fallbackUrl,
                              fit: BoxFit.cover,
                              headers: headers,
                              errorBuilder: (_, __, ___) => ProfileImage(),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                isUser: ticket.user['id'] > 0 ? true : false,
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await ConfirmationDialogWidget.show(
                      context: context,
                      title: 'Delete ticket',
                      subTitle: 'Are you sure you want to delete this ticket?',
                      negativeButtonText: 'Cancel',
                      positiveButtonText: 'Delete',
                    );
                    if (!context.mounted) return;
                    if (confirm == true) {
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
                    if (!context.mounted) return;
                    if (confirm == true) {
                      context.read<TicketBloc>().add(ArchiveTicket(ticket.id));
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
                    if (!context.mounted) return;
                    if (confirm == true) {
                      context.read<TicketBloc>().add(
                        UnArchiveTicket(ticket.id),
                      );
                    }
                  }
                },
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider(
                        create: (context) =>
                            sl<TicketBloc>()..add(LoadSingleTicket(ticket.id)),
                        child: TicketForm(ticketId: ticket.id),
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  if (result == true) {
                    context.read<TicketBloc>().add(
                      const TicketsLoad(1, showSkeleton: true),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: 7),
                    if ((ticket.partner['name'] ?? '').isNotEmpty)
                      Text(
                        ticket.partner['name'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black45,
                        ),
                      ),

                    if ((ticket.ticketType['name'] ?? '').isNotEmpty)
                      Text(
                        ticket.ticketType['name'],
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),

                    if (ticket.tags.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      buildChips(ticket.tags, isDark),
                      const SizedBox(height: 3),
                    ],
                    if (ticket.slaDeadline.isNotEmpty)
                      Text(
                        formatDeadline(ticket.slaDeadline),
                        style: TextStyle(
                          color:
                              DateTime.tryParse(
                                    ticket.slaDeadline,
                                  )?.isBefore(DateTime.now()) ==
                                  true
                              ? AppColors.primary
                              : Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },

          isLoading: state.isLoading,
          headerBuilder: (stageId, stageName, items) {
            final isPriorityGroup = groupBy == 'priority';
            return Container(
              width: 292,
              // Right inset matches the card's dot position (card margin + padding).
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isPriorityGroup)
                    PriorityStarsWidget(priority: stageName)
                  else ...[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          // Long names are ellipsized; the count stays visible.
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  stageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                ' ${items.length}',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (groupBy == 'stage') ...[
                    PopupMenuButton<String>(
                      offset: const Offset(0, 28),
                      color: isDark ? Colors.grey[850] : Colors.white,
                      // Zero padding so the dots align with the card dots below.
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 16,
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit_stage':
                            final bloc = context.read<TicketBloc>();
                            final stage = await bloc.ticketListUseCase.getStage(
                              stageId,
                            );

                            List<Map<String, dynamic>>? emailTemplates =
                                await bloc.ticketListUseCase.loadEmailTemplate(
                                  stageId,
                                );

                            List<Map<String, dynamic>>? smsTemplates =
                                await bloc.ticketListUseCase.loadSmsTemplate(
                                  stageId,
                                );

                            if (!context.mounted) return;

                            showStageUpdateBottomSheet(
                              context,
                              stageId: stageId,
                              currentStageName: stageName,
                              defaultEmail: stage['template_id'],
                              defaultSms: stage['sms_template_id'],
                              defaultSequence: stage['sequence'],
                              emailTemplates: emailTemplates,
                              smsTemplates: smsTemplates,
                            );
                            break;
                          case 'delete_stage':
                            final confirm = await ConfirmationDialogWidget.show(
                              context: context,
                              title: 'Delete stage',
                              subTitle:
                                  'Are you sure you want to delete this stage?',
                              negativeButtonText: 'Cancel',
                              positiveButtonText: 'Delete',
                            );
                            if (!context.mounted) return;
                            if (confirm == true) {
                              context.read<TicketBloc>().add(
                                DeleteStage(stageId),
                              );
                            }
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'edit_stage',
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedPencilEdit02,
                                color: isDark ? Colors.white : Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Edit Stage',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete_stage',
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedDelete02,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete Stage',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (state.isScheduleLoading)
          Positioned.fill(
            child: Center(
              child: LoadingAnimationWidget.fourRotatingDots(
                color: AppColors.primary,
                size: 50,
              ),
            ),
          ),
      ],
    ),
  );
}
