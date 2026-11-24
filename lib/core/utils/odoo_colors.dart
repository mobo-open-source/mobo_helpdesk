import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

Color odooColor(int index) {
  const odooColors = [
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFF8800),
    Color(0xFF9E9E9E),
    Color(0xFF00897B),
    Color(0xFF1E88E5),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
  ];

  return odooColors[index % odooColors.length];
}
Color getTicketStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'new':
      return Colors.blue;

    case 'inprogress':
    case 'in_progress':
    case 'in progress':
    case 'on hold':
      return Colors.orange;
    case 'solved':
      return Colors.green;

    case 'cancelled':
    case 'canceled':
      return Colors.red;

    default:
      return Colors.grey;
  }
}

Color generateColorFromString(String text) {
  const palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    AppColors.infoIcon,
    AppColors.successIcon,
    AppColors.warningIcon,
    AppColors.errorIcon,
    AppColors.textSecondary,
  ];

  final index = text.codeUnits.fold(0, (sum, c) => sum + c) % palette.length;
  return palette[index];
}
