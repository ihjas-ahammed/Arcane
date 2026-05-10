import 'package:flutter/material.dart';

class AppTheme {
  // Operator HUD palette — amber-on-midnight tactical
  static const Color fhBgDeepDark = Color(0xFF04060E); // Deep background
  static const Color fhBgDark = Color(0xFF0D1426); // Panel
  static const Color fhBgMedium = Color(0xFF101A30); // Elevated
  static const Color fhBorderColor = Color(0xFF1B2A38);

  static const Color fhTextPrimary = Color(0xFFEAECF3);
  static const Color fhTextSecondary = Color(0xFFA8B3C7);
  static const Color fhTextDisabled = Color(0xFF5E6C87);

  // Accents
  static const Color fhAccentRed = Color(0xFFFF5470); // Alert
  static const Color fhAccentTeal = Color(0xFF5FE1D8); // Cyan secondary
  static const Color fhAccentTealFixed = Color(0xFF5FE1D8);
  static const Color fhAccentGold = Color(0xFFFFB547); // Amber primary
  static const Color fhAccentPurple = Color(0xFF8A6FE2);
  static const Color fhAccentGreen = Color(0xFF4AF3C2);
  static const Color fhAccentOrange = Color(0xFFFFB547);

  static const String fontDisplay = 'RobotoCondensed';
  static const String fontBody = 'OpenSans';

  // Method to generate ThemeData with a dynamic primary accent color
  static ThemeData getThemeData({required Color primaryAccent}) {
    final Brightness accentBrightness =
        ThemeData.estimateBrightnessForColor(primaryAccent);
    final Color onPrimaryAccent =
        accentBrightness == Brightness.dark ? fhTextPrimary : fhBgDeepDark;

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: fhBgDeepDark,

      // Smooth transitions
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      }),

      colorScheme: ColorScheme.dark(
        primary: primaryAccent,
        secondary: primaryAccent,
        surface: fhBgDeepDark, // Dark surface for Valorant feel
        error: fhAccentRed,
        onPrimary: onPrimaryAccent,
        onSecondary: onPrimaryAccent,
        onSurface: fhTextPrimary,
        onError: fhTextPrimary,
      ),

      fontFamily: fontBody,

      appBarTheme: AppBarTheme(
        backgroundColor: fhBgDeepDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: fhTextPrimary, size: 22),
        titleTextStyle: const TextStyle(
          fontFamily: fontDisplay,
          color: fhTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20, // Reduced from 24
          letterSpacing: 2.0, // Wide tracking for headers
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 42, // Reduced from 56
            letterSpacing: 1.5),
        displayMedium: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 32, // Reduced from 40
            letterSpacing: 1.2),
        displaySmall: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24, // Reduced from 32
            letterSpacing: 1.0),
        headlineLarge: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22), // Reduced from 24
        headlineMedium: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18, // Reduced from 20
            letterSpacing: 0.5),
        headlineSmall: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16), // Reduced from 18
        titleLarge: TextStyle(
            fontFamily: fontBody,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16),
        titleMedium: TextStyle(
            fontFamily: fontBody,
            color: fhTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14),
        titleSmall: TextStyle(
            fontFamily: fontBody,
            color: fhTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
        bodyLarge: TextStyle(
            fontFamily: fontBody,
            color: fhTextPrimary,
            fontSize: 15,
            height: 1.5),
        bodyMedium: TextStyle(
            fontFamily: fontBody,
            color: fhTextSecondary,
            fontSize: 13,
            height: 1.4),
        bodySmall: TextStyle(
            fontFamily: fontBody,
            color: fhTextSecondary,
            fontSize: 11,
            height: 1.3),
        labelLarge: TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: onPrimaryAccent,
          textStyle: const TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          // Cut corners (Beveled)
          shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))), 
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryAccent, width: 1.0),
          foregroundColor: primaryAccent,
          textStyle: const TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fhBgDark.withValues(alpha: 0.8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
            color: fhTextSecondary.withValues(alpha: 0.5),
            fontFamily: fontBody,
            fontSize: 13),
        labelStyle: const TextStyle(
            color: fhTextSecondary,
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 0.5),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero, // Sharp edges for inputs
          borderSide: BorderSide(color: fhBorderColor, width: 1.0),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: fhBorderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: primaryAccent, width: 1.0),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: fhBgDeepDark,
        titleTextStyle: const TextStyle(
            fontFamily: fontDisplay,
            color: fhTextPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0),
        contentTextStyle: const TextStyle(
            fontFamily: fontBody, color: fhTextSecondary, fontSize: 14),
        shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
            side: BorderSide(
                color: fhBorderColor.withValues(alpha: 0.5), width: 1)),
        elevation: 8,
      ),

      // ... other themes ...
      iconTheme: const IconThemeData(color: fhTextSecondary, size: 22),
      dividerTheme: DividerThemeData(
          color: fhBorderColor.withValues(alpha: 0.3), thickness: 1),
    );
  }
}
