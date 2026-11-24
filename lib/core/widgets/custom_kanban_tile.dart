import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/priority_stars_widget.dart';

/// A reusable card-style tile designed specifically for use inside [CustomKanbanBoard].
///
/// This widget provides a consistent look for Kanban items with built-in support for:
/// - Custom content ([child])
/// - Priority display using [PriorityStarsWidget]
/// - User avatar / indicator
/// - Context menu with Archive / Unarchive and Delete actions
/// - Dark mode support
///
/// The tile is wrapped in an [InkWell] for tap gestures and includes a [PopupMenuButton]
/// for quick actions.
class CustomKanbanTile extends StatelessWidget {
  final Widget child;
  final Widget activityWidget;
  final Widget bulletWidget;
  final Widget userImageWidget;
  final String? title;
  final VoidCallback? onTap;
  final Function(String)? onSelected;
  final bool isArchiveView;
  final String priority;
  final bool isUser;
  final bool isBottom;

  const CustomKanbanTile({
    super.key,
    required this.child,
    required this.activityWidget,
    required this.bulletWidget,
    required this.userImageWidget,
    this.title,
    this.onTap,
    this.onSelected,
    this.isArchiveView = false,
    required this.priority,
    this.isUser = false,
    this.isBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850]! : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade200,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: child,
                ),
                if (isBottom) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isUser) userImageWidget,
                          const SizedBox(width: 10),
                          bulletWidget,
                        ],
                      ),
                      Row(
                        children: [
                          activityWidget,
                          const SizedBox(width: 10),
                          PriorityStarsWidget(priority: priority),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
            Positioned(
              top: -8,
              right: -8,
              child: PopupMenuButton<String>(
                offset: const Offset(0, 28),
                color: isDark ? Colors.grey[850]! : Colors.white,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                onSelected: onSelected,
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete $title',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: isArchiveView ? 'unarchive' : 'archive',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: isArchiveView
                              ? HugeIcons.strokeRoundedRestoreBin
                              : HugeIcons.strokeRoundedArchive,
                          color: isDark ? AppColors.white : Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isArchiveView ? 'Unarchive $title' : 'Archive $title',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
