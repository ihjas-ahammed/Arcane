import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class AppTheme {
  static bool get isLightTheme => JweTheme.isLight;

  // Operator HUD palette — amber-on-midnight tactical.
  // Light mode delegates to the JweTheme warm-paper system.
  static Color get fhBgDeepDark => isLightTheme ? JweTheme.bgBase : const Color(0xFF04060E); // Deep background (Canvas)
  static Color get fhBgDark => isLightTheme ? JweTheme.panel : const Color(0xFF0D1426); // Panel background
  static Color get fhBgMedium => isLightTheme ? JweTheme.panel2 : const Color(0xFF101A30); // Elevated
  static Color get fhBorderColor => isLightTheme ? JweTheme.border : const Color(0xFF1B2A38);

  static Color get fhTextPrimary => isLightTheme ? JweTheme.textWhite : const Color(0xFFEAECF3);
  static Color get fhTextSecondary => isLightTheme ? JweTheme.textMid : const Color(0xFFA8B3C7);
  static Color get fhTextDisabled => isLightTheme ? JweTheme.textMuted : const Color(0xFF5E6C87);

  // Accents
  static Color get fhAccentRed => isLightTheme ? const Color(0xFFBE123C) : const Color(0xFFFF5470); // Alert
  static Color get fhAccentTeal => isLightTheme ? const Color(0xFF0F766E) : const Color(0xFF5FE1D8); // Cyan secondary
  static Color get fhAccentTealFixed => isLightTheme ? const Color(0xFF0F766E) : const Color(0xFF5FE1D8);

  static Color _fhAccentGold = const Color(0xFF00AEFF); // Sky blue primary
  static Color get fhAccentGold => JweTheme.isLight ? JweTheme.accentAmber : _fhAccentGold;
  static set fhAccentGold(Color val) => _fhAccentGold = val;

  static Color get fhAccentPurple => isLightTheme ? const Color(0xFF6D28D9) : const Color(0xFF8A6FE2);
  static Color get fhAccentGreen => isLightTheme ? const Color(0xFF047857) : const Color(0xFF4AF3C2);

  static Color _fhAccentOrange = const Color(0xFF00AEFF);
  static Color get fhAccentOrange => JweTheme.isLight ? JweTheme.accentAmber : _fhAccentOrange;
  static set fhAccentOrange(Color val) => _fhAccentOrange = val;

  // Light Theme Colors (Operator HUD Tactical Light — warm paper/stone system)
  static const Color fhLightBgDeepDark = Color(0xFFEDE8E0);
  static const Color fhLightBgDark = Color(0xFFFAF8F5);
  static const Color fhLightBgMedium = Color(0xFFF3EFE7);
  static const Color fhLightBorderColor = Color(0xFFD4CDC0);

  static const Color fhLightTextPrimary = Color(0xFF211D18);
  static const Color fhLightTextSecondary = Color(0xFF4A443C);
  static const Color fhLightTextDisabled = Color(0xFF7A7266);

  static const String fontDisplay = 'RobotoCondensed';
  static const String fontBody = 'OpenSans';

  // ThemeData construction is expensive and a fresh instance invalidates every
  // Theme.of dependent in the tree, so results are memoized. The palette getters
  // used below depend only on (primaryAccent, isLightTheme), which is the key.
  static final Map<(int, bool), ThemeData> _themeCache = {};

  // Method to generate ThemeData with a dynamic primary accent color
  static ThemeData getThemeData({required Color primaryAccent, bool isLightTheme = false}) {
    final key = (primaryAccent.toARGB32(), isLightTheme);
    final cached = _themeCache[key];
    if (cached != null) return cached;
    if (_themeCache.length > 32) _themeCache.clear();
    return _themeCache[key] = _buildThemeData(
        primaryAccent: primaryAccent, isLightTheme: isLightTheme);
  }

  static ThemeData _buildThemeData(
      {required Color primaryAccent, required bool isLightTheme}) {
    final Brightness accentBrightness =
        ThemeData.estimateBrightnessForColor(primaryAccent);
    final Color onPrimaryAccent =
        isLightTheme ? Colors.white : (accentBrightness == Brightness.dark ? fhTextPrimary : fhBgDeepDark);

    final bgDeep = isLightTheme ? fhLightBgDeepDark : fhBgDeepDark;
    final bgDark = isLightTheme ? fhLightBgDark : fhBgDark;
    final textPrimary = isLightTheme ? fhLightTextPrimary : fhTextPrimary;
    final textSecondary = isLightTheme ? fhLightTextSecondary : fhTextSecondary;
    final borderColor = isLightTheme ? fhLightBorderColor : fhBorderColor;

    return ThemeData(
      brightness: isLightTheme ? Brightness.light : Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: bgDeep,

      // Smooth transitions
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      }),

      colorScheme: isLightTheme
          ? ColorScheme.light(
              primary: primaryAccent,
              secondary: primaryAccent,
              surface: bgDeep,
              error: fhAccentRed,
              onPrimary: onPrimaryAccent,
              onSecondary: onPrimaryAccent,
              onSurface: textPrimary,
              onError: textPrimary,
            )
          : ColorScheme.dark(
              primary: primaryAccent,
              secondary: primaryAccent,
              surface: bgDeep, // Dark surface for Valorant feel
              error: fhAccentRed,
              onPrimary: onPrimaryAccent,
              onSecondary: onPrimaryAccent,
              onSurface: textPrimary,
              onError: textPrimary,
            ),

      fontFamily: fontBody,

      appBarTheme: AppBarTheme(
        backgroundColor: bgDeep,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20, // Reduced from 24
          letterSpacing: 2.0, // Wide tracking for headers
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 42, // Reduced from 56
            letterSpacing: 1.5),
        displayMedium: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 32, // Reduced from 40
            letterSpacing: 1.2),
        displaySmall: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24, // Reduced from 32
            letterSpacing: 1.0),
        headlineLarge: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22), // Reduced from 24
        headlineMedium: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18, // Reduced from 20
            letterSpacing: 0.5),
        headlineSmall: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16), // Reduced from 18
        titleLarge: TextStyle(
            fontFamily: fontBody,
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16),
        titleMedium: TextStyle(
            fontFamily: fontBody,
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14),
        titleSmall: TextStyle(
            fontFamily: fontBody,
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
        bodyLarge: TextStyle(
            fontFamily: fontBody,
            color: textPrimary,
            fontSize: 15,
            height: 1.5),
        bodyMedium: TextStyle(
            fontFamily: fontBody,
            color: textSecondary,
            fontSize: 13,
            height: 1.4),
        bodySmall: TextStyle(
            fontFamily: fontBody,
            color: textSecondary,
            fontSize: 11,
            height: 1.3),
        labelLarge: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
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
        fillColor: bgDark.withValues(alpha: 0.8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.5),
            fontFamily: fontBody,
            fontSize: 13),
        labelStyle: TextStyle(
            color: textSecondary,
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero, // Sharp edges for inputs
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: primaryAccent, width: 1.0),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: bgDeep,
        titleTextStyle: TextStyle(
            fontFamily: fontDisplay,
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0),
        contentTextStyle: TextStyle(
            fontFamily: fontBody, color: textSecondary, fontSize: 14),
        shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
            side: BorderSide(
                color: borderColor.withValues(alpha: 0.5), width: 1)),
        elevation: 8,
      ),

      iconTheme: IconThemeData(color: textSecondary, size: 22),
      dividerTheme: DividerThemeData(
          color: borderColor.withValues(alpha: 0.3), thickness: 1),
    );
  }
}
