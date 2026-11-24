import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

class IconConfig {
  final IconData icon;
  final Color color;

  const IconConfig(this.icon, this.color);
}

IconConfig getIconConfig(String iconName, bool isDark) {
  final tasks = IconConfig(HugeIcons.strokeRoundedCheckList, Colors.blue);
  final phone = IconConfig(Icons.phone, Colors.green);
  final users = IconConfig(HugeIcons.strokeRoundedUserGroup, Colors.indigo);
  final lifeRing = IconConfig(
    HugeIcons.strokeRoundedChartRing,
    AppColors.primary,
  );
  final envelope = IconConfig(Icons.mail_outline, Color(0xFFB89300));
  final calendar = IconConfig(Icons.calendar_month_sharp, Colors.purple);
  final check = IconConfig(Icons.check_circle_outline, Colors.green);
  final times = IconConfig(HugeIcons.strokeRoundedTime02, Colors.red);
  final clock = IconConfig(Icons.query_builder_sharp, Colors.amber);
  final upload = IconConfig(Icons.upload_outlined, Colors.deepOrange);

  final map = {
    // Font Awesome names, used by Odoo 19 and earlier.
    'fa-tasks': tasks,
    'fa-phone': phone,
    'fa-users': users,
    'fa-life-ring': lifeRing,
    'fa-envelope': envelope,
    'fa-calendar': calendar,
    'fa-check': check,
    'fa-times': times,
    'fa-clock': clock,
    'fa-upload': upload,
    // Material Symbols names, used by Odoo 20 for the same activity types.
    'checklist': tasks,
    'phone': phone,
    'group': users,
    'support_agent': lifeRing,
    'mail': envelope,
    'calendar_today': calendar,
    'check': check,
    'close': times,
    'schedule': clock,
    'upload': upload,
  };

  final config =
      // No activity type (or an unknown one): the Mobo Events calendar glyph
      // in the brand colour, not a grey clock.
      map[iconName] ??
      const IconConfig(HugeIcons.strokeRoundedCalendar03, AppColors.primary);

  return IconConfig(
    config.icon,
    isDark ? config.color.withValues(alpha: 0.8) : config.color,
  );
}
