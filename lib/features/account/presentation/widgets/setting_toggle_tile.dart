import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/core/widgets/mobo_toggle.dart';

/// A reusable settings tile with a toggle switch.
///
/// This widget is used for boolean settings such as:
/// - Dark mode
/// - Biometric authentication
/// - Notifications
/// - Feature flags
///
/// It displays:
/// - An icon representing the setting
/// - A title and subtitle describing the setting
/// - A toggle switch for enabling/disabling the option
///
/// The toggle UI adapts to the current theme (light/dark mode)
/// and uses a consistent app color scheme.
class SettingsToggleTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          MoboToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
