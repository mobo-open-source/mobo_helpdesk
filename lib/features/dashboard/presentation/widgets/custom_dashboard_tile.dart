import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

/// A utility class containing static widget builders for consistent dashboard UI components.
///
/// This class provides reusable, themed dashboard tiles and cards used throughout the
/// dashboard screen. All widgets are designed to support both light and dark themes
/// and follow the app's design system.
///
/// Usage:
/// ```dart
/// CustomDashboardTile.tileStyle(
///   isDark: isDark,
///   child: Column(...),
/// );
/// ```
class CustomDashboardTile {
  /// Creates a styled container with elevation and border used as the base for
  /// major dashboard sections.
  ///
  /// Parameters:
  ///   - [child]: The content to be displayed inside the tile.
  ///   - [isDark]: Whether the current theme is dark mode.
  static Widget tileStyle({required Widget child, required bool isDark}) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
        ),
        child: child,
      ),
    );
  }

  /// Creates a colorful gradient top card used for quick statistics
  /// (e.g., Tickets Open, High Priority, Urgent).
  ///
  /// Parameters:
  ///   - [title]: Label shown below the icon.
  ///   - [value]: The main numeric/statistical value displayed prominently.
  ///   - [icon]: Can be either [IconData] or a [HugeIcon] from the hugeicons package.
  ///   - [g1], [g2], [g3], [g4]: Gradient colors from top to bottom.
  ///   - [isDark]: Current theme mode.
  ///   - [onTap]: Optional callback when the card is tapped (for navigation).
  static Widget topCard(
    String title,
    String value,
    dynamic icon,
    Color g1,
    Color g2,
    Color g3,
    Color g4,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [g1, g2, g3, g4],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: (icon is IconData)
                  ? Icon(icon, size: 20, color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: HugeIcon(
                        icon: icon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 3),

            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a section container with a title and three equally spaced small cards.
  ///
  /// Commonly used for "Avg Open Hours" and "Failed Tickets" sections.
  ///
  /// Parameters:
  ///   - [title]: Section heading.
  ///   - [isDark]: Current theme mode.
  ///   - [children]: Must contain exactly 3 [Widget]s (usually [smallCard]s).
  static Widget sectionContainer({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 10),
              Expanded(child: children[1]),
              const SizedBox(width: 10),
              Expanded(child: children[2]),
            ],
          ),
        ),
      ],
    );
  }

  /// Creates a compact card used inside [sectionContainer].
  ///
  /// Parameters:
  ///   - [title]: Small label (e.g., "Tickets", "High Priority").
  ///   - [value]: The main value to display.
  ///   - [isDark]: Current theme mode.
  ///   - [onTap]: Optional tap handler.
  static Widget smallCard(
    String title,
    String value,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A soft pastel statistic card with a colored background, a corner icon,
  /// a label and a prominent value. Used across dashboard sections
  /// (Tickets, High Priority, Urgent, Open, Unassigned, Failed).
  ///
  /// Parameters:
  ///   - [title]: Small label shown at the top.
  ///   - [value]: The main value displayed prominently.
  ///   - [accent]: Accent color driving the background tint, icon and value.
  ///   - [icon]: Corner icon (HugeIcon) representing the metric.
  ///   - [isDark]: Current theme mode.
  ///   - [onTap]: Optional tap handler.
  static Widget statCard({
    required String title,
    required String value,
    required Color accent,
    required dynamic icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? accent.withValues(alpha: 0.18)
              : accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? accent.withValues(alpha: 0.35)
                : accent.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.35 : 0.20),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: (icon is IconData)
                      ? Icon(icon, size: 24, color: accent)
                      : HugeIcon(icon: icon, size: 24, color: accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 35,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget activeCard(
    String title,
    String value,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a performance-style card used in team support sections
  /// (Open, Unassigned, Urgent, Failed).
  ///
  /// Parameters:
  ///   - [value]: Numeric value shown at the top.
  ///   - [title]: Label shown below the value.
  ///   - [isDark]: Current theme mode.
  ///   - [onTap]: Optional navigation handler.
  static Widget performanceCard(
    String value,
    String title,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates a large performance metric container used in the "My Performance" section.
  ///
  /// Supports optional edit icon for daily targets and can display either an icon
  /// or an image asset.
  ///
  /// Parameters:
  ///   - [color]: Primary accent color for the icon background.
  ///   - [icon]: IconData to display (used when [imageAsset] is null).
  ///   - [imageAsset]: Asset path for custom image (e.g., reward.png).
  ///   - [title]: Main metric title (e.g., "Closed Tickets").
  ///   - [subTitle]: Description of the metric.
  ///   - [endTitle]: The prominent value/rate shown on the right.
  ///   - [isDark]: Current theme mode.
  ///   - [showEditIcon]: Whether to show the pencil edit icon (only for Daily Target).
  ///   - [onEditTap]: Callback when edit icon is tapped.
  ///   - [onTap]: Callback when the entire container is tapped (for navigation).
  static Widget performanceContainers({
    required Color color,
    IconData? icon,
    String? imageAsset,
    required String title,
    required String subTitle,
    required String endTitle,
    required bool isDark,

    bool showEditIcon = false,
    VoidCallback? onEditTap,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.grey.shade50, Colors.white],
                ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? color.withValues(alpha: 0.6)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset,
                        width: 24,
                        height: 24,
                        color: isDark ? Colors.white : color,
                      )
                    : Icon(
                        icon,
                        size: 24,
                        color: isDark ? Colors.white : color,
                      ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    subTitle,
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  endTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (showEditIcon) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onEditTap,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedPencilEdit02,
                      size: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget tileTitleText({required String title, required bool isDark}) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static Widget tileValueText({required String value, required bool isDark}) {
    return Text(
      value,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      textAlign: TextAlign.end,
    );
  }
}
