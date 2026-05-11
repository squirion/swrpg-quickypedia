import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the SWRPG Quickypedia app — sourced from the
/// `swrpg-weapon-view` design handoff (claude.ai/design). Keep
/// presentational logic here; widgets should not hard-code colors.
class AppColors {
  static const bg = Color(0xFF0C0F14);
  static const bg2 = Color(0xFF11151C);
  static const panel = Color(0xFF1A1F27);
  static const panel2 = Color(0xFF232A34);
  static const panel3 = Color(0xFF2C3441);

  static const ink = Color(0xFFE7ECF2);
  static const inkDim = Color(0xFFAAB4C2);
  static const inkFaint = Color(0xFF6B7585);

  static const line = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const lineStrong = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)

  static const accent = Color(0xFF7A9BC4);
  static const accentDim = Color(0x2E7A9BC4); // alpha 0.18

  // Stat-block specifics from the design CSS.
  static const statTabBg = Color(0xFF2A323E);
  static const statTabInk = Color(0xFFB4C5DC);
  static const statTabInkItalic = Color(0xFF9FB8D6);
  static const statFieldBorder = Color(0xFF3A4452);
  static const statHexLight = Color(0xFF7793B1);
  static const statHexDark = Color(0xFF4E6781);
  static const statHexRail = Color(0xFF6F8DB0);
}

/// Helpers around the three Google Fonts the design specifies.
///
/// `body` (Inter) is the default. `display` (Roboto Condensed) is used
/// for titles, stat labels, breadcrumbs — anywhere the design uses a
/// condensed, tracked, all-caps treatment. `mono` (JetBrains Mono) is
/// reserved for metadata: section numbers, URLs, footer text.
class AppFonts {
  static TextStyle body([TextStyle? base]) =>
      GoogleFonts.inter(textStyle: base);

  static TextStyle display([TextStyle? base]) =>
      GoogleFonts.robotoCondensed(textStyle: base);

  static TextStyle mono([TextStyle? base]) =>
      GoogleFonts.jetBrainsMono(textStyle: base);
}

ThemeData buildAppTheme() {
  final baseScheme = const ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.accent,
    secondary: AppColors.accent,
    onPrimary: Colors.black,
    onSurface: AppColors.ink,
    error: Color(0xFFE57373),
  );

  // Build a Material TextTheme that defaults to Inter, with title/headline
  // sizes overridden to Roboto Condensed to mirror the design's display use.
  final body = GoogleFonts.interTextTheme(
    ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
  );
  final display = GoogleFonts.robotoCondensedTextTheme(ThemeData.dark().textTheme);
  final textTheme = body.copyWith(
    headlineLarge: display.headlineLarge?.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: display.headlineMedium?.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: display.headlineSmall?.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: display.titleLarge?.copyWith(color: AppColors.ink),
    titleMedium: display.titleMedium?.copyWith(color: AppColors.ink),
    titleSmall: display.titleSmall?.copyWith(color: AppColors.inkDim),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: baseScheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppFonts.display(
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: 0.04,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.inkDim),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AppColors.lineStrong),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lineStrong),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkDim),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.panel2,
      contentTextStyle: TextStyle(color: AppColors.ink),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.panel2,
      side: const BorderSide(color: AppColors.lineStrong),
      labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.inkDim),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        textStyle: AppFonts.display(
          const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.lineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      hintStyle: const TextStyle(color: AppColors.inkFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
    dividerColor: AppColors.line,
    iconTheme: const IconThemeData(color: AppColors.inkDim),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.panel,
    ),
  );
}
