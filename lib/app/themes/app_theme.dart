import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// Main brand color used across the app.
  static const Color primaryColor = Color(0xFFC03355);

  /// Secondary supporting color (usually backgrounds / contrast).
  static const Color secondaryColor = Color(0xFFffffff);

  /// Light mode theme configuration.
  ///
  /// Includes:
  /// • Manrope font
  /// • Seed-based color scheme
  /// • Light scaffold background
  /// • Styled AppBar, Buttons and Inputs
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    textTheme: GoogleFonts.manropeTextTheme(),
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: Colors.grey.shade50,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade50,
      foregroundColor: Colors.black,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 23,
        fontFamily: GoogleFonts.manrope().fontFamily,
        color: Colors.black,
      ),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );

  /// Dark mode theme configuration.
  ///
  /// Optimized for low-light UI with:
  /// • Dark scaffold background
  /// • Same brand color identity
  /// • Consistent component styling
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    textTheme: GoogleFonts.manropeTextTheme(),
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: const Color(0xFF181A20),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF181A20),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 23,
        fontFamily: GoogleFonts.manrope().fontFamily,
      ),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );
}
