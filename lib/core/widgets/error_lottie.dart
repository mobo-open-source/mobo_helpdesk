import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

/// A reusable error state widget with Lottie animation, title, subtitle, and retry button.
///
/// This widget is designed to be shown when an error occurs while loading data,
/// such as network failure, server error, or unexpected issues. It features a
/// prominent error animation and a clear "Retry" action button.
///
/// The widget automatically adapts its colors and styling for both light and dark themes.
class ErrorLottie extends StatelessWidget {
  final String title;
  final String subTitle;
  final VoidCallback onPressed;

  const ErrorLottie({
    super.key,
    required this.title,
    required this.subTitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/Error_404.json',
              width: 300,
              height: 300,
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
            const SizedBox(height: 8),
            Text(
              subTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
