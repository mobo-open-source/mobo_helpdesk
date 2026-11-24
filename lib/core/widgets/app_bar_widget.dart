import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A reusable custom AppBar widget for the app.
///
/// This widget provides a consistent app bar with:
/// - Custom title
/// - Optional back button with custom icon
/// - Support for dark/light mode colors
/// - Custom actions
class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isDark;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const AppBarWidget({
    super.key,
    required this.title,
    required this.isDark,
    this.automaticallyImplyLeading = false,
    this.onBack,
    this.actions,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: backgroundColor,

      leadingWidth: 30,
      leading: onBack != null
          ? IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
                size: 28,
              ),
              onPressed: onBack,
            )
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
