import 'package:flutter/material.dart';

class AppTheme {
  // Valorant-inspired color palette (BASE colors)
  static const Color fhBgDeepDark = Color(0xFF0F1923); 
  static const Color fhBgDark = Color(0xFF1A2838); 
  static const Color fhBgMedium = Color(0xFF203040); 
  static const Color fhBgLight = Color(0xFF2C3E50); 
  static const Color fhBorderColor = Color(0xFF384B5F); 

  static const Color fhTextPrimary = Color(0xFFEAEAEA); 
  static const Color fhTextSecondary = Color(0xFFB0B8C0); 
  static const Color fhTextDisabled = Color(0xFF707880);

  // Fixed accents (won't change with task theme)
  static const Color fhAccentRed = Color(0xFFFD4556); // Valorant Red (e.g., for errors, critical actions)
  static const Color fhAccentTealFixed = Color(0xFF00F8F8); 
  static const Color fhAccentTeal = Color(0xFF00F8F8); // Default system teal (can be used if no task color)
  static const Color fhAccentGold = Color(0xFFFFE075); 
  static const Color fhAccentPurple = Color(0xFF8A2BE2); 
  static const Color fhAccentGreen = Color(0xFF4CAF50); 
  static const Color fhAccentOrange = Color(0xFFFF7043); 

  static const String fontDisplay = 'RobotoCondensed'; 
  static const String fontBody = 'OpenSans';

  
  // Method to generate ThemeData with a dynamic primary accent color
  static ThemeData getThemeData({required Color primaryAccent}) {
    final Brightness accentBrightness = ThemeData.estimateBrightnessForColor(primaryAccent);
    final Color onPrimaryAccent = accentBrightness == Brightness.dark ? fhTextPrimary : fhBgDark;

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent, // Dynamic primary accent
      scaffoldBackgroundColor: fhBgDeepDark,

      colorScheme: ColorScheme.dark(
        primary: primaryAccent, // Dynamic primary accent
        secondary: primaryAccent, // Also use dynamic accent for secondary for consistency
        surface: fhBgDark, 
        error: fhAccentRed,
        onPrimary: onPrimaryAccent, // Text on dynamic primary accent
        onSecondary: onPrimaryAccent, // Text on dynamic secondary accent
        onSurface: fhTextPrimary, 
        onError: fhTextPrimary,
      ),

      fontFamily: fontBody,

      appBarTheme: AppBarTheme(
        backgroundColor: fhBgDark, 
        elevation: 0, 
        centerTitle: true,
        iconTheme: const IconThemeData(color: fhTextSecondary, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          color: fhTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20, 
          letterSpacing: 1.1,
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 48, letterSpacing: 1.2),
        displayMedium: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 36, letterSpacing: 1.1),
        displaySmall: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontWeight: FontWeight.w600, fontSize: 28),
        headlineLarge: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        headlineMedium: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        headlineSmall: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontWeight: FontWeight.w500, fontSize: 18),
        titleLarge: TextStyle(fontFamily: fontBody, color: fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        titleMedium: TextStyle(fontFamily: fontBody, color: fhTextPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        titleSmall: TextStyle(fontFamily: fontBody, color: fhTextSecondary, fontSize: 12, fontWeight: FontWeight.w400),
        bodyLarge: TextStyle(fontFamily: fontBody, color: fhTextPrimary, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(fontFamily: fontBody, color: fhTextSecondary, fontSize: 13, height: 1.4),
        bodySmall: TextStyle(fontFamily: fontBody, color: fhTextSecondary, fontSize: 11, height: 1.3),
        labelLarge: TextStyle(fontFamily: fontBody, color: onPrimaryAccent, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 14), 
        labelMedium: TextStyle(fontFamily: fontBody, color: fhTextSecondary, letterSpacing: 0.8, fontSize: 12),
        labelSmall: TextStyle(fontFamily: fontBody, color: fhTextSecondary, letterSpacing: 0.5, fontSize: 10),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent, // Dynamic accent for buttons
          foregroundColor: onPrimaryAccent,
          textStyle: TextStyle(fontFamily: fontBody, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
          elevation: 2,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryAccent, width: 1.5), // Dynamic accent
          foregroundColor: primaryAccent, // Dynamic accent
          textStyle: TextStyle(fontFamily: fontBody, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent, // Dynamic accent
          textStyle: TextStyle(fontFamily: fontBody, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fhBgMedium.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: fhTextSecondary.withOpacity(0.7), fontFamily: fontBody, fontSize: 13),
        labelStyle: TextStyle(color: fhTextSecondary, fontFamily: fontBody, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.0),
          borderSide: const BorderSide(color: fhBorderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.0),
          borderSide: const BorderSide(color: fhBorderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.0),
          borderSide: BorderSide(color: primaryAccent, width: 1.5), // Dynamic accent
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.0),
          borderSide: BorderSide(color: fhAccentRed.withOpacity(0.7), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.0),
          borderSide: const BorderSide(color: fhAccentRed, width: 1.5),
        ),
        prefixIconColor: fhTextSecondary,
        suffixIconColor: fhTextSecondary,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryAccent, // Dynamic accent for progress
        linearTrackColor: fhBgMedium,
        circularTrackColor: fhBgMedium,
        linearMinHeight: 5,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: fhBgMedium,
        labelStyle: TextStyle(color: fhTextPrimary, fontFamily: fontBody, fontSize: 11),
        selectedColor: primaryAccent, // Dynamic accent
        secondarySelectedColor: primaryAccent.withOpacity(0.7), // Dynamic accent
        disabledColor: fhBorderColor.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: fhBorderColor.withOpacity(0.3)),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primaryAccent, // Dynamic accent
        unselectedLabelColor: fhTextSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primaryAccent, width: 2.0), // Dynamic accent
        ),
        labelStyle: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        unselectedLabelStyle: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w500, fontSize: 13, letterSpacing: 0.5),
        indicatorSize: TabBarIndicatorSize.label,
      ),

      iconTheme: const IconThemeData(
        color: fhTextSecondary,
        size: 20,
      ),

      tooltipTheme: TooltipThemeData(
        preferBelow: false,
        textStyle: TextStyle(fontSize: 11, color: fhBgDark, fontFamily: fontBody),
        decoration: BoxDecoration(
          color: fhAccentGold.withOpacity(0.95),
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: fhBorderColor.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),

      cardTheme: CardThemeData(
        color: fhBgDark, 
        elevation: 0, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2.0), 
          side: BorderSide(color: fhBorderColor.withOpacity(0.4), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: fhTextSecondary,
        textColor: fhTextPrimary,
        tileColor: Colors.transparent, 
        selectedTileColor: primaryAccent.withOpacity(0.1), // Dynamic accent
        titleTextStyle: TextStyle(fontFamily: fontBody, fontSize: 14, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(fontFamily: fontBody, fontSize: 12, color: fhTextSecondary),
        minVerticalPadding: 12,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return primaryAccent; // Dynamic accent
          }
          return fhTextSecondary.withOpacity(0.6);
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return primaryAccent.withOpacity(0.3); // Dynamic accent
          }
          return fhBorderColor.withOpacity(0.3);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: fhBgMedium,
        titleTextStyle: TextStyle(fontFamily: fontDisplay, color: fhTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(fontFamily: fontBody, color: fhTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        elevation: 5,
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: fhBgDeepDark,
          selectedItemColor: primaryAccent, // Dynamic Accent
          unselectedItemColor: fhTextSecondary.withOpacity(0.8),
          selectedLabelStyle: TextStyle(fontSize: 10, fontFamily: fontBody, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          unselectedLabelStyle: TextStyle(fontSize: 10, fontFamily: fontBody, letterSpacing: 0.5),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
      ),
    );
  }
}