import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — refined 2026 palette built around the Vlotter brand green.
// Imports across the app should prefer these constants over inline hex values.
// ─────────────────────────────────────────────────────────────────────────────

// Brand
const kBrandGreen = Color(0xFF8CC63F);
const kBrandGreenDark = Color(0xFF6FA12D);
const kBrandGreenDeep = Color(0xFF52801F);
const kBrandGreenSoft = Color(0xFFEAF4D9);
const kBrandGreenSubtle = Color(0xFFF4F9E8);

// Legacy alias kept for files that already imported it.
const kAppGreen = kBrandGreen;

// Surface & background
const kBackground = Color(0xFFF6F7F2);
const kSurface = Color(0xFFFFFFFF);
const kSurfaceMuted = Color(0xFFFAFBF6);
const kSurfaceHover = Color(0xFFF2F4ED);

// Borders
const kBorder = Color(0xFFE3E7DC);
const kBorderStrong = Color(0xFFCDD3C2);
const kBorderSubtle = Color(0xFFEFF1E9);

// Text
const kTextPrimary = Color(0xFF1B2418);
const kTextSecondary = Color(0xFF3D453A);
const kTextTertiary = Color(0xFF6A7264);
const kTextMuted = Color(0xFF8B927F);
const kTextInverse = Color(0xFFFFFFFF);

// Semantic
const kSuccess = Color(0xFF4D7A1A);
const kSuccessBg = Color(0xFFEBF5D9);
const kSuccessBorder = Color(0xFFB5D582);

const kDanger = Color(0xFFB83828);
const kDangerBg = Color(0xFFFCEDEA);
const kDangerBorder = Color(0xFFECB5B0);

const kWarning = Color(0xFF8F6306);
const kWarningBg = Color(0xFFFEF3CB);
const kWarningBorder = Color(0xFFE8D386);

const kInfo = Color(0xFF1F5C97);
const kInfoBg = Color(0xFFE4F0FC);
const kInfoBorder = Color(0xFFB4D2F1);

// Radius
const kRadiusXs = 8.0;
const kRadiusSm = 10.0;
const kRadiusMd = 12.0;
const kRadiusLg = 16.0;
const kRadiusXl = 20.0;
const kRadius2xl = 24.0;
const kRadiusPill = 999.0;

// Spacing — internal reference for screens that previously used loose magic
// numbers. Existing screens can adopt these gradually.
const kSpace1 = 4.0;
const kSpace2 = 8.0;
const kSpace3 = 12.0;
const kSpace4 = 16.0;
const kSpace5 = 20.0;
const kSpace6 = 24.0;
const kSpace8 = 32.0;
const kSpace10 = 40.0;

// Shadow presets — soft and used sparingly.
const kShadowSoft = [
  BoxShadow(color: Color(0x0A101510), blurRadius: 18, offset: Offset(0, 6)),
];

const kShadowCard = [
  BoxShadow(color: Color(0x0F121712), blurRadius: 24, offset: Offset(0, 10)),
];

// ─────────────────────────────────────────────────────────────────────────────
// Typography — Inter via Google Fonts. Sizes lifted slightly vs the previous
// scale, line-heights opened up for readability, letter-spacing tightened on
// large display sizes.
// ─────────────────────────────────────────────────────────────────────────────

TextTheme _buildTextTheme() {
  TextStyle base(double size, FontWeight weight, Color color,
      {double height = 1.45, double letterSpacing = 0}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  return TextTheme(
    displayLarge: base(40, FontWeight.w800, kTextPrimary,
        height: 1.15, letterSpacing: -0.6),
    displayMedium: base(34, FontWeight.w800, kTextPrimary,
        height: 1.18, letterSpacing: -0.5),
    displaySmall: base(28, FontWeight.w700, kTextPrimary,
        height: 1.2, letterSpacing: -0.4),
    headlineLarge: base(26, FontWeight.w700, kTextPrimary,
        height: 1.25, letterSpacing: -0.3),
    headlineMedium: base(22, FontWeight.w700, kTextPrimary,
        height: 1.28, letterSpacing: -0.25),
    headlineSmall: base(19, FontWeight.w700, kTextPrimary, height: 1.3),
    titleLarge: base(17, FontWeight.w700, kTextPrimary, height: 1.35),
    titleMedium: base(15, FontWeight.w600, kTextPrimary, height: 1.4),
    titleSmall: base(13.5, FontWeight.w600, kTextPrimary, height: 1.4),
    bodyLarge: base(15.5, FontWeight.w500, kTextSecondary, height: 1.5),
    bodyMedium: base(14, FontWeight.w500, kTextSecondary, height: 1.5),
    bodySmall: base(12.5, FontWeight.w500, kTextTertiary, height: 1.45),
    labelLarge: base(14, FontWeight.w600, kTextPrimary, height: 1.3),
    labelMedium: base(12.5, FontWeight.w600, kTextTertiary,
        height: 1.3, letterSpacing: 0.1),
    labelSmall: base(11.5, FontWeight.w600, kTextMuted,
        height: 1.3, letterSpacing: 0.4),
  );
}

ThemeData buildAppTheme() {
  final textTheme = _buildTextTheme();

  final colorScheme = ColorScheme.fromSeed(
    seedColor: kBrandGreen,
    primary: kBrandGreen,
    onPrimary: kTextInverse,
    secondary: kBrandGreenDark,
    surface: kSurface,
    onSurface: kTextPrimary,
    error: kDanger,
    onError: kTextInverse,
    outline: kBorderStrong,
    outlineVariant: kBorder,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBackground,
    canvasColor: kBackground,
    fontFamily: GoogleFonts.inter().fontFamily,
    fontFamilyFallback: const ['Inter', 'Segoe UI', 'sans-serif'],
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,

    iconTheme: const IconThemeData(color: kTextSecondary, size: 22),
    primaryIconTheme: const IconThemeData(color: kTextInverse, size: 22),

    appBarTheme: AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 20,
      iconTheme: const IconThemeData(color: kTextPrimary, size: 22),
      actionsIconTheme: const IconThemeData(color: kTextSecondary, size: 22),
      toolbarHeight: 64,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: kTextPrimary,
      ),
      shape: const Border(bottom: BorderSide(color: kBorder, width: 1)),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: kTextPrimary,
      contentTextStyle: GoogleFonts.inter(
        color: kTextInverse,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      hintStyle: GoogleFonts.inter(
        color: kTextMuted,
        fontWeight: FontWeight.w400,
        fontSize: 14.5,
      ),
      labelStyle: GoogleFonts.inter(
        color: kTextTertiary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: kBrandGreenDark,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBrandGreen, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kDanger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kDanger, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    cardTheme: CardThemeData(
      color: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: kBorder),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return kBrandGreen.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.pressed)) {
            return kBrandGreenDeep;
          }
          if (states.contains(WidgetState.hovered)) {
            return kBrandGreenDark;
          }
          return kBrandGreen;
        }),
        foregroundColor: const WidgetStatePropertyAll(kTextInverse),
        overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusPill)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return kTextMuted;
          }
          return kTextSecondary;
        }),
        backgroundColor: const WidgetStatePropertyAll(kSurface),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return const BorderSide(color: kBrandGreenDark, width: 1.4);
          }
          return const BorderSide(color: kBorderStrong);
        }),
        overlayColor: const WidgetStatePropertyAll(kSurfaceHover),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusPill)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return kTextMuted;
          }
          if (states.contains(WidgetState.pressed)) {
            return kBrandGreenDeep;
          }
          return kBrandGreenDark;
        }),
        overlayColor: const WidgetStatePropertyAll(kBrandGreenSubtle),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return kTextMuted;
          }
          return kTextSecondary;
        }),
        overlayColor: const WidgetStatePropertyAll(kSurfaceHover),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceMuted,
      selectedColor: kBrandGreenSoft,
      disabledColor: kSurfaceHover,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kBrandGreenDeep,
      ),
      side: const BorderSide(color: kBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showCheckmark: false,
    ),

    dividerTheme: const DividerThemeData(
      color: kBorder,
      thickness: 1,
      space: 1,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x16101510),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        side: const BorderSide(color: kBorder),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: kTextPrimary,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: kTextSecondary),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kTextPrimary,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      textStyle: GoogleFonts.inter(
        color: kTextInverse,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 250),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kBrandGreen,
      circularTrackColor: kBorder,
      linearTrackColor: kBorder,
    ),
  );
}
