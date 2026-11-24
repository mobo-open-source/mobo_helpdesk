import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/core/widgets/custom_list_tile.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/widgets/schedule_activity_dialog.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/dialog_button_style.dart';
import '../../../../core/widgets/list_group_widgets.dart';
import '../bloc/ticket_bloc.dart';
import 'activity_icon_map.dart';

class ActivityDetailsDialog extends StatefulWidget {
  final String ticketName;
  final int ticketId;
  final List<Map<String, dynamic>> activities;
  final VoidCallback onSchedule;

  const ActivityDetailsDialog({
    super.key,
    required this.ticketName,
    required this.ticketId,
    required this.activities,
    required this.onSchedule,
  });

  @override
  State<ActivityDetailsDialog> createState() => _ActivityDetailsDialogState();
}

class _ActivityDetailsDialogState extends State<ActivityDetailsDialog> {
  final Map<String, bool> expanded = {
    "Overdue": false,
    "Today": false,
    "Planned": false,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    List<Map<String, dynamic>> today = [];
    List<Map<String, dynamic>> planned = [];
    List<Map<String, dynamic>> overdue = [];

    for (var activity in widget.activities) {
      final dateStr = activity['end_date'];
      if (dateStr == null || dateStr.isEmpty) continue;

      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      final activityDate = DateTime(date.year, date.month, date.day);

      if (activityDate == todayDate) {
        today.add(activity);
      } else if (activityDate.isAfter(todayDate)) {
        planned.add(activity);
      } else {
        overdue.add(activity);
      }
    }

    final hasActivities = widget.activities.isNotEmpty;

    // Same layout as the Mobo Events activities dialog: a plain Dialog with a
    // text header, the list (or a centred empty state) and, when there are
    // activities, a "+" in the header instead of a bottom button.
    return Dialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activities',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          widget.ticketName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (hasActivities)
                    IconButton(
                      onPressed: widget.onSchedule,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : const Color(0xFFF2F4F6),
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                      color: Colors.black54,
                    ),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: hasActivities
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildSection(
                            context,
                            "Overdue",
                            overdue,
                            isDark,
                            Colors.red,
                          ),
                          buildSection(
                            context,
                            "Today",
                            today,
                            isDark,
                            const Color(0xFFB89300),
                          ),
                          buildSection(
                            context,
                            "Planned",
                            planned,
                            isDark,
                            const Color(0xFF228B22),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 48,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No activities found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your first activity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: widget.onSchedule,
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedAdd01,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: const Text('Create Activity'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                elevation: 0,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSection(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> list,
    bool isDark,
    Color stageColor,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();

    final isExpanded = expanded[title] ?? true;

    return ListGroupWidgets(
      isActivity: true,
      groupName: title,
      groupColor: stageColor,
      description:
          '${list.length} ${list.length != 1 ? "activities" : "activity"}',
      expanded: isExpanded,
      onTap: () {
        setState(() {
          expanded[title] = !isExpanded;
        });
      },
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Column(
                children: list
                    .map(
                      (activity) =>
                          buildActivityTile(context, activity, isDark),
                    )
                    .toList(),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Who the activity is for: the person, the role when it was given to one
  /// (Odoo 20), or both.
  String _assignee(Map<String, dynamic> activity) {
    final user = activity['user_name'];
    final role = activity['role_name'];
    final names = [
      if (user is String && user.isNotEmpty) user,
      if (role is String && role.isNotEmpty) role,
    ];
    return names.join(' · ');
  }

  Widget buildActivityTile(
    BuildContext context,
    Map<String, dynamic> activity,
    bool isDark,
  ) {
    final config = getIconConfig(activity['icon'], isDark);

    return CustomListTile(
      isMoreShow: false,
      isActivity: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? config.color.withValues(alpha: 0.6)
                      : config.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    config.icon,
                    size: 24,
                    color: isDark ? Colors.white : config.color,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _assignee(activity),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            activity['summary'] is String ? activity['summary'] : '',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          if ((activity['phone'] is String) &&
              (activity['phone'] as String).isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              activity['phone'] as String,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            activity['end_date'] ?? '',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DialogButtonStyle.negativeButton(
                  context: context,
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ScheduleActivityDialog(
                        ticketId: widget.ticketId,
                        activity: activity,
                        isEdit: true,
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.pop(context);
                      context.read<TicketBloc>().add(const TicketsLoad(1));
                    }
                  },
                  title: 'Edit',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DialogButtonStyle.successButton(
                  context: context,
                  onPressed: () {
                    context.read<TicketBloc>().add(
                      MarkDoneActivity(activity['id']),
                    );

                    Navigator.pop(context);
                    context.read<TicketBloc>().add(const TicketsLoad(1));
                  },
                  title: 'Done',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
