import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

/// A settings list tile with a dropdown selector for configurable options.
///
/// This widget is commonly used in settings screens to allow users to
/// select values such as language, currency, or timezone.
///
/// Features:
/// - Displays an icon, title, and subtitle for context
/// - Shows a dropdown menu with selectable items
/// - Supports dynamic key-based value extraction (`displayKey`)
/// - Prevents duplicate dropdown entries
/// - Automatically validates current selection against available items
/// - Shows a loading indicator overlay when `isLoading` is true
///
/// The dropdown adapts to theme (dark/light mode) and ensures a compact
/// UI suitable for settings panels.
///
/// Example use cases:
/// - Language selection
/// - Currency selection
/// - Timezone selection
class SettingDropdownTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final String value;
  final List<Map<String, dynamic>> items;
  final String displayKey;
  final ValueChanged<String?> onChanged;
  final bool isLoading;

  const SettingDropdownTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.displayKey,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final uniqueItems = <String, Map<String, dynamic>>{};
    for (var item in items) {
      final key = item[displayKey].toString();
      uniqueItems[key] = item;
    }
    final filteredItems = uniqueItems.values.toList();

    final exists = filteredItems.any(
      (item) => item[displayKey].toString() == value,
    );
    final dropdownValue = exists ? value : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: HugeIcon(
        icon: icon,
        color: isDark ? Colors.grey.shade400 : Colors.black,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  value: dropdownValue,
                  isExpanded: true,
                  items: items.map((item) {
                    final itemValue = item[displayKey].toString();
                    return DropdownMenuItem<String>(
                      value: itemValue,
                      child: Text(
                        itemValue,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,

                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    width: 120,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    offset: const Offset(0, 4),
                  ),

                  buttonStyleData: ButtonStyleData(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  menuItemStyleData: const MenuItemStyleData(height: 40),
                ),
              ),
            ),
            if (isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: LoadingAnimationWidget.threeArchedCircle(
                    color: isDark ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
