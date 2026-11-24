import 'package:flutter/material.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/card_heading_divider.dart';
import '../../data/models/ticket_model.dart';
import 'activity_icon_map.dart';

class ActivityWidget extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;

  const ActivityWidget({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final config = getIconConfig(icon, isDark);
    return GestureDetector(
      onTap: onTap,
      child: Icon(config.icon, size: 18, color: config.color),
    );
  }
}

const _overdueColor = AppColors.primary;
const _todayColor = Color(0xFFB89300);
const _plannedColor = Color(0xFF228B22);

/// How an activity's deadline reads and what colour it takes: red when
/// overdue, amber today, green when planned. Matches the activities dialog.
({String label, Color color}) activityDue(dynamic deadline) {
  final raw = deadline is String ? deadline : '';
  final date = DateTime.tryParse(raw);
  if (date == null) return (label: raw, color: Colors.grey);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return (label: 'Today', color: _todayColor);
  if (day.isBefore(today))
    return (label: 'Overdue · $raw', color: _overdueColor);
  return (label: raw, color: _plannedColor);
}

/// A compact list of a ticket's activities for the list view: icon, what it is
/// and when it is due. Shows [maxShown] and a "+N more" for the rest.
class ActivityChipsRow extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final int maxShown;

  const ActivityChipsRow({
    super.key,
    required this.activities,
    this.maxShown = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shown = activities.take(maxShown).toList();
    final more = activities.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in shown) _chip(a, isDark),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '+$more more',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(Map<String, dynamic> a, bool isDark) {
    final config = getIconConfig(a['icon'] is String ? a['icon'] : '', isDark);
    final due = activityDue(a['end_date'] ?? a['date_deadline']);
    final summary =
        (a['summary'] is String && (a['summary'] as String).isNotEmpty)
        ? a['summary'] as String
        : (a['name'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: due.color.withValues(alpha: isDark ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: isDark ? Colors.white : due.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$summary${due.label.isNotEmpty ? ' · ${due.label}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : due.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Activities" card on the ticket form: every activity scheduled on the
/// ticket. Read-only; activities are created and edited from the list.
class TicketActivitiesCard extends StatelessWidget {
  final int ticketId;
  final List rawActivities;

  const TicketActivitiesCard({
    super.key,
    required this.ticketId,
    required this.rawActivities,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activities = TicketModel.parseActivities(rawActivities);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                activities.isEmpty
                    ? 'Activities'
                    : 'Activities (${activities.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        CardHeadingDivider(isDark: isDark),
        const SizedBox(height: 20),
        if (activities.isEmpty)
          Text(
            'No activities scheduled.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          )
        else
          for (var i = 0; i < activities.length; i++)
            _tile(activities[i], isDark, isLast: i == activities.length - 1),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> a, bool isDark, {bool isLast = false}) {
    final config = getIconConfig(a['icon'] is String ? a['icon'] : '', isDark);
    final due = activityDue(a['end_date']);
    final assignee = [
      if ((a['user_name'] ?? '').toString().isNotEmpty) a['user_name'],
      if ((a['role_name'] ?? '').toString().isNotEmpty) a['role_name'],
    ].join(' · ');
    final title = (a['name'] ?? '').toString();
    final typeField = a['activity_type_id'];
    final typeName = (typeField is List && typeField.length > 1)
        ? typeField[1].toString()
        : '';
    final note = a['note'] is String
        ? (a['note'] as String)
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
        : '';
    // The title is already the summary (or the type when there is none), so
    // the second line shows the type, or the note, rather than repeating it.
    final summary = [
      typeName,
      note,
    ].firstWhere((t) => t.isNotEmpty && t != title, orElse: () => '');

    return Padding(
      // No gap after the last row, so the card's bottom gap matches its top.
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: isDark ? 0.6 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              config.icon,
              size: 20,
              color: isDark ? Colors.white : config.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                if (assignee.isNotEmpty)
                  Text(
                    assignee,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          if (due.label.isNotEmpty)
            Text(
              due.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: due.color,
              ),
            ),
        ],
      ),
    );
  }
}
