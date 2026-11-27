import 'package:flutter/material.dart';
import '../../app/themes/app_colors.dart';

class CustomDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    required bool isDark,
    DateTime? initialDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: TextStyle(
                color: isDark ? Colors.white : const Color(0xff1E1E1E),
              ),
              bodyMedium: TextStyle(
                color: isDark ? Colors.white : const Color(0xff1E1E1E),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],

              hintStyle: TextStyle(
                color: isDark ? Colors.white : Color(0xff1E1E1E),
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.normal,
                fontSize: 15,
                height: 1.0,
                letterSpacing: 0.0,
              ),

              labelStyle: TextStyle(
                color: isDark ? Colors.white : Color(0xff1E1E1E),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: Colors.grey[850]!,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    surface: Colors.white,
                  ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,

              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              dividerColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,

              dayForegroundColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white : Colors.black;
              }),

              todayForegroundColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.blue;
              }),
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
