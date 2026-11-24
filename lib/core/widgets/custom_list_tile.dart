import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/themes/app_colors.dart';

/// A reusable list tile widget with consistent card styling and built-in context menu.
///
/// Designed for use in lists where each item needs a clean card appearance with:
/// - Custom content via [child]
/// - Optional tap gesture
/// - Context menu (more_vert) with **Delete** and optional **Archive/Unarchive** actions
/// - Consistent theming for both light and dark modes
/// - Proper spacing and shadow for a modern look
///
/// This widget is particularly useful for settings screens, data lists, ticket lists,
/// or any scrollable list of actionable items.
class CustomListTile extends StatelessWidget {
  final Widget child;
  final String? title;
  final VoidCallback? onTap;
  final Function(String)? onSelected;
  final bool isArchiveView;
  final bool isArchiveShow;
  final bool isMoreShow;
  final bool isActivity;

  const CustomListTile({
    super.key,
    required this.child,
    this.title,
    this.onTap,
    this.onSelected,
    this.isArchiveView = false,
    this.isArchiveShow = true,
    this.isMoreShow = true,
    this.isActivity = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          gradient: (isActivity)
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    isDark ? Colors.grey[800]! : Colors.grey.shade50,
                    isDark ? Colors.grey[900]! : Colors.white,
                  ],
                )
              : null,
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(child: child),
              if (isMoreShow)
                // Height matches the heading's line so the dots sit level
                // with it instead of centred in a 48px touch target.
                SizedBox(
                  width: 48,
                  height: 24,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    // Card padding is 16: shift the menu so its top and right edges
                    // meet the card's top and right edges.
                    offset: const Offset(16, -16),
                    color: isDark ? Colors.grey[900] : Colors.white,
                    icon: Icon(
                      Icons.more_vert,
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
                      if (isArchiveShow)
                        PopupMenuItem<String>(
                          value: isArchiveView ? 'unarchive' : 'archive',
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: isArchiveView
                                    ? HugeIcons.strokeRoundedRestoreBin
                                    : HugeIcons.strokeRoundedArchive,
                                color: isDark ? Colors.white : Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isArchiveView
                                    ? 'Unarchive $title'
                                    : 'Archive $title',
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
      ),
    );
  }
}
