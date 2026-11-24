import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

/// A reusable empty state widget with Lottie animation, title, optional subtitle,
/// and an action button.
///
/// This widget is designed to be displayed when a list, search result, or data set
/// is empty. It features a friendly ghost Lottie animation and one outlined
/// action button:
/// - while a filter is active ([isCondition]), only "Clear All Filters"
///   ([onPressed]) is offered;
/// - otherwise, "Retry" ([onRetry]) reloads the list, when a callback is given.
///
/// The widget automatically adapts to light and dark themes.
class EmptyLottie extends StatelessWidget {
  final String title;
  final String? subTitle;
  final bool isCondition;
  final VoidCallback? onPressed;
  final VoidCallback? onRetry;

  /// How the content scrolls. Give [AlwaysScrollableScrollPhysics] when this
  /// sits directly under a `RefreshIndicator`: an empty list is shorter than
  /// the screen, and without it nothing can be pulled down.
  final ScrollPhysics? physics;

  /// Centres the ghost, text and action button in the available space instead
  /// of stacking them from the top.
  final bool centered;

  const EmptyLottie({
    super.key,
    required this.title,
    this.subTitle,
    this.isCondition = false,
    this.onPressed,
    this.onRetry,
    this.physics,
    this.centered = false,
  });

  /// Full size of the ghost, and the smallest it shrinks to.
  static const double _maxGhostSize = 300;
  static const double _minGhostSize = 100;

  /// Room the title, subtitle and button take under the ghost.
  static const double _textAndActionHeight = 130;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // With the keyboard open there is far less than 300 + text to work
        // with, which overflowed the screen. The ghost gives way first, and
        // whatever still does not fit scrolls instead of overflowing.
        final ghostSize = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - _textAndActionHeight)
                  .clamp(_minGhostSize, _maxGhostSize)
                  .toDouble()
            : _maxGhostSize;

        if (centered && constraints.maxHeight.isFinite) {
          return _pinned(context, constraints, ghostSize, isDark);
        }

        return SingleChildScrollView(
          physics: physics,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/empty_ghost.json',
                  width: ghostSize,
                  height: ghostSize,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (isCondition) ...[
                  const SizedBox(height: 8),
                  Text(
                    subTitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _outlinedAction(
                    label: 'Clear All Filters',
                    onPressed: onPressed,
                    isDark: isDark,
                  ),
                ] else if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  _outlinedAction(
                    label: 'Retry',
                    onPressed: onRetry,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ghost(double size) => Lottie.asset(
    'assets/empty_ghost.json',
    width: size,
    height: size,
    fit: BoxFit.contain,
    repeat: true,
    animate: true,
  );

  Widget _pinned(
    BuildContext context,
    BoxConstraints constraints,
    double ghostSize,
    bool isDark,
  ) {
    final action = isCondition
        ? _outlinedAction(
            label: 'Clear All Filters',
            onPressed: onPressed,
            isDark: isDark,
          )
        : (onRetry != null
              ? _outlinedAction(
                  label: 'Retry',
                  onPressed: onRetry,
                  isDark: isDark,
                )
              : null);

    return LayoutBuilder(
      builder: (context, inner) => SingleChildScrollView(
        physics: physics,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: inner.maxHeight),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ghost(ghostSize),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (isCondition) ...[
                  const SizedBox(height: 8),
                  Text(
                    subTitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 10), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinedAction({
    required String label,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w400),
      ),
    );
  }
}
