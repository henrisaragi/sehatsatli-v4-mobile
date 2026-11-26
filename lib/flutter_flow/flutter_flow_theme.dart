// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

const kThemeModeKey = '__theme_mode__';

SharedPreferences? _prefs;

abstract class FlutterFlowTheme {
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();

  static ThemeMode get themeMode {
    final darkMode = _prefs?.getBool(kThemeModeKey);
    return darkMode == null
        ? ThemeMode.system
        : darkMode
            ? ThemeMode.dark
            : ThemeMode.light;
  }

  static void saveThemeMode(ThemeMode mode) => mode == ThemeMode.system
      ? _prefs?.remove(kThemeModeKey)
      : _prefs?.setBool(kThemeModeKey, mode == ThemeMode.dark);

  /// Material theme for widgets that don't read FlutterFlowTheme directly
  /// (dialogs, bottom sheets, pickers, snackbars, ink/hover, default text).
  static ThemeData materialTheme(Brightness brightness) {
    final t =
        brightness == Brightness.dark ? DarkModeTheme() : LightModeTheme();
    final isDark = brightness == Brightness.dark;
    final hover = t.primaryText.withValues(alpha: isDark ? 0.06 : 0.04);
    return ThemeData(
      brightness: brightness,
      useMaterial3: false,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.primary,
        onPrimary: t.onPrimary,
        secondary: t.secondary,
        onSecondary: t.onSecondary,
        error: t.error,
        onError: t.onError,
        surface: t.secondaryBackground,
        onSurface: t.primaryText,
      ),
      primaryColor: t.primary,
      scaffoldBackgroundColor: t.primaryBackground,
      canvasColor: t.primaryBackground,
      cardColor: t.secondaryBackground,
      dividerColor: t.alternate,
      hoverColor: hover,
      highlightColor: hover,
      splashColor: t.primaryText.withValues(alpha: isDark ? 0.08 : 0.06),
      focusColor: t.primary.withValues(alpha: 0.12),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.primary,
        selectionColor: t.primary.withValues(alpha: 0.3),
        selectionHandleColor: t.primary,
      ),
      textTheme: ThemeData(brightness: brightness)
          .textTheme
          .apply(bodyColor: t.primaryText, displayColor: t.primaryText),
      iconTheme: IconThemeData(color: t.primaryText),
      dialogTheme: DialogThemeData(backgroundColor: t.secondaryBackground),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.secondaryBackground,
        modalBackgroundColor: t.secondaryBackground,
      ),
      popupMenuTheme: PopupMenuThemeData(color: t.secondaryBackground),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? t.surfaceVariant : const Color(0xFF343A40),
        contentTextStyle:
            TextStyle(color: isDark ? t.primaryText : Colors.white),
        actionTextColor: t.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.primary),
    );
  }

  static FlutterFlowTheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkModeTheme()
        : LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late Color onPrimary;
  late Color primaryContainer;
  late Color onPrimaryContainer;
  late Color onSecondary;
  late Color secondaryContainer;
  late Color onSecondaryContainer;
  late Color onAccent;
  late Color accentContainer;
  late Color onAccentContainer;
  late Color onBackground;
  late Color onSurface;
  late Color surfaceVariant;
  late Color onSurfaceVariant;
  late Color onSuccess;
  late Color onWarning;
  late Color onError;
  late Color onInfo;
  late Color transparent;
  late Color fullContrast;
  late Color fullContrast40;
  late Color fullContrast60;
  late Color onPrimary50;
  late Color onPrimary30;
  late Color onPrimary80;
  late Color onSurface50;
  late Color onPrimary10;
  late Color onPrimary70;
  late Color fullContrast10;
  late Color fullContrast80;
  late Color secondary30;
  late Color info20;
  late Color secondary20;
  late Color primary10;
  late Color onPrimary20;
  late Color onBackground90;
  late Color success10;
  late Color success50;
  late Color surface50;

  FFDesignTokens get designToken => FFDesignTokens(this);

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = const Color(0xFF17B273);
  late Color secondary = const Color(0xFFE67E22);
  late Color tertiary = const Color(0xFF2980B9);
  late Color alternate = const Color(0xFFE5E7EB);
  late Color primaryText = const Color(0xFF1F2937);
  late Color secondaryText = const Color(0xFF555555);
  late Color primaryBackground = const Color(0xFFFFFFFF);
  late Color secondaryBackground = const Color(0xFFF8F9FA);
  late Color accent1 = const Color(0xFFE7F7F1);
  late Color accent2 = const Color(0xFFFDEDDF);
  late Color accent3 = const Color(0xFFEBF5FB);
  late Color accent4 = const Color(0xFFFDEDEC);
  late Color success = const Color(0xFF17B273);
  late Color warning = const Color(0xFFE67E22);
  late Color error = const Color(0xFFC0392B);
  late Color info = const Color(0xFF2980B9);

  late Color onPrimary = const Color(0xFFFFFFFF);
  late Color primaryContainer = const Color(0x1A17B273);
  late Color onPrimaryContainer = const Color(0xFF1A1A1A);
  late Color onSecondary = const Color(0xFFFFFFFF);
  late Color secondaryContainer = const Color(0x1AE67E22);
  late Color onSecondaryContainer = const Color(0xFF1A1A1A);
  late Color onAccent = const Color(0xFFFFFFFF);
  late Color accentContainer = const Color(0x1A2980B9);
  late Color onAccentContainer = const Color(0xFF1A1A1A);
  late Color onBackground = const Color(0xFF1A1A1A);
  late Color onSurface = const Color(0xFF1A1A1A);
  late Color surfaceVariant = const Color(0xFFE7F7F1);
  late Color onSurfaceVariant = const Color(0xFF64748B);
  late Color onSuccess = const Color(0xFFFFFFFF);
  late Color onWarning = const Color(0xFFFFFFFF);
  late Color onError = const Color(0xFFFFFFFF);
  late Color onInfo = const Color(0xFFFFFFFF);
  late Color transparent = const Color(0x00000000);
  late Color fullContrast = const Color(0xFF000000);
  late Color fullContrast40 = const Color(0x66000000);
  late Color fullContrast60 = const Color(0x99000000);
  late Color onPrimary50 = const Color(0x80FFFFFF);
  late Color onPrimary30 = const Color(0x4DFFFFFF);
  late Color onPrimary80 = const Color(0xCCFFFFFF);
  late Color onSurface50 = const Color(0x801A1A1A);
  late Color onPrimary10 = const Color(0x1AFFFFFF);
  late Color onPrimary70 = const Color(0xB3FFFFFF);
  late Color fullContrast10 = const Color(0x1A000000);
  late Color fullContrast80 = const Color(0xCC000000);
  late Color secondary30 = const Color(0x4DE67E22);
  late Color info20 = const Color(0x332980B9);
  late Color secondary20 = const Color(0x33E67E22);
  late Color primary10 = const Color(0x1A17B273);
  late Color onPrimary20 = const Color(0x33FFFFFF);
  late Color onBackground90 = const Color(0xE61A1A1A);
  late Color success10 = const Color(0x1A17B273);
  late Color success50 = const Color(0x8017B273);
  late Color surface50 = const Color(0x80FFFFFF);
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  String get displayLargeFamily => 'Poppins';
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 57.0,
        height: 1.12,
      );
  String get displayMediumFamily => 'Poppins';
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 45.0,
        height: 1.16,
      );
  String get displaySmallFamily => 'Poppins';
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 22.0,
        height: 1.22,
      );
  String get headlineLargeFamily => 'Poppins';
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 32.0,
        height: 1.2,
      );
  String get headlineMediumFamily => 'Poppins';
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 28.0,
        height: 1.25,
      );
  String get headlineSmallFamily => 'Poppins';
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 24.0,
        height: 1.3,
      );
  String get titleLargeFamily => 'Poppins';
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => GoogleFonts.poppins(
        fontWeight: FontWeight.w500,
        fontSize: 18.0,
        height: 1.27,
      );
  String get titleMediumFamily => 'Poppins';
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 17.0,
        height: 1.35,
      );
  String get titleSmallFamily => 'Poppins';
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        height: 1.4,
      );
  String get labelLargeFamily => 'Inter';
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 13.0,
        height: 1.33,
      );
  String get labelMediumFamily => 'Inter';
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 12.0,
        height: 1.38,
      );
  String get labelSmallFamily => 'Inter';
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 10.0,
        height: 1.27,
      );
  String get bodyLargeFamily => 'Inter';
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => GoogleFonts.inter(
        fontWeight: FontWeight.normal,
        fontSize: 15.0,
        height: 1.5,
      );
  String get bodyMediumFamily => 'Inter';
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => GoogleFonts.inter(
        fontWeight: FontWeight.normal,
        fontSize: 13.0,
        height: 1.47,
      );
  String get bodySmallFamily => 'Inter';
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => GoogleFonts.inter(
        fontWeight: FontWeight.normal,
        fontSize: 11.0,
        height: 1.38,
      );
}

/// Zinc-based dark palette (neutral greys, no blue tint): near-black page,
/// raised cards, lighter hover/selected surfaces. Brand hues are lifted a
/// little so text and icons keep contrast on dark surfaces; tinted badge
/// backgrounds are translucent so they work on any surface.
class DarkModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = const Color(0xFF17B273);
  late Color secondary = const Color(0xFFF0903E);
  late Color tertiary = const Color(0xFF4FA3E0);
  late Color alternate = const Color(0xFF2A2A2E);
  late Color primaryText = const Color(0xFFF4F4F5);
  late Color secondaryText = const Color(0xFFA1A1AA);
  late Color primaryBackground = const Color(0xFF0B0B0D);
  late Color secondaryBackground = const Color(0xFF18181B);
  late Color accent1 = const Color(0x2617B273);
  late Color accent2 = const Color(0x26F0903E);
  late Color accent3 = const Color(0x264FA3E0);
  late Color accent4 = const Color(0x26E5484D);
  late Color success = const Color(0xFF2ECC8F);
  late Color warning = const Color(0xFFF0903E);
  late Color error = const Color(0xFFE5484D);
  late Color info = const Color(0xFF4FA3E0);

  late Color onPrimary = const Color(0xFFFFFFFF);
  late Color primaryContainer = const Color(0x2617B273);
  late Color onPrimaryContainer = const Color(0xFFF4F4F5);
  late Color onSecondary = const Color(0xFFFFFFFF);
  late Color secondaryContainer = const Color(0x26F0903E);
  late Color onSecondaryContainer = const Color(0xFFF4F4F5);
  late Color onAccent = const Color(0xFFFFFFFF);
  late Color accentContainer = const Color(0x264FA3E0);
  late Color onAccentContainer = const Color(0xFFF4F4F5);
  late Color onBackground = const Color(0xFFF4F4F5);
  late Color onSurface = const Color(0xFFF4F4F5);
  late Color surfaceVariant = const Color(0xFF27272A);
  late Color onSurfaceVariant = const Color(0xFFA1A1AA);
  late Color onSuccess = const Color(0xFFFFFFFF);
  late Color onWarning = const Color(0xFFFFFFFF);
  late Color onError = const Color(0xFFFFFFFF);
  late Color onInfo = const Color(0xFFFFFFFF);
  late Color transparent = const Color(0x00000000);
  late Color fullContrast = const Color(0xFFFFFFFF);
  late Color fullContrast40 = const Color(0x66FFFFFF);
  late Color fullContrast60 = const Color(0x99FFFFFF);
  late Color onPrimary50 = const Color(0x80FFFFFF);
  late Color onPrimary30 = const Color(0x4DFFFFFF);
  late Color onPrimary80 = const Color(0xCCFFFFFF);
  late Color onSurface50 = const Color(0x80F4F4F5);
  late Color onPrimary10 = const Color(0x1AFFFFFF);
  late Color onPrimary70 = const Color(0xB3FFFFFF);
  late Color fullContrast10 = const Color(0x1AFFFFFF);
  late Color fullContrast80 = const Color(0xCCFFFFFF);
  late Color secondary30 = const Color(0x4DF0903E);
  late Color info20 = const Color(0x334FA3E0);
  late Color secondary20 = const Color(0x33F0903E);
  late Color primary10 = const Color(0x2617B273);
  late Color onPrimary20 = const Color(0x33FFFFFF);
  late Color onBackground90 = const Color(0xE6F4F4F5);
  late Color success10 = const Color(0x1A2ECC8F);
  late Color success50 = const Color(0x802ECC8F);
  late Color surface50 = const Color(0x8018181B);
}

class FFDesignTokens {
  const FFDesignTokens(this.theme);
  final FlutterFlowTheme theme;
  FFSpacing get spacing => const FFSpacing();
  FFRadius get radius => const FFRadius();
  FFShadows get shadow => FFShadows(theme);
}

class FFSpacing {
  const FFSpacing();
  double get none => 0.0;
  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get xl => 32.0;
  double get xxl => 48.0;
  double get xxxl => 64.0;
}

class FFRadius {
  const FFRadius();
  double get none => 0.0;
  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 12.0;
  double get lg => 16.0;
  double get xl => 24.0;
  double get xxl => 32.0;
  double get full => 9999.0;
}

class FFShadows {
  const FFShadows(this.theme);
  final FlutterFlowTheme theme;
  BoxShadow get none => const BoxShadow(
      blurRadius: 0.0,
      color: const Color(0x00000000),
      offset: const Offset(0.0, 0.0),
      spreadRadius: 0.0);
  BoxShadow get xs => const BoxShadow(
      blurRadius: 2.0,
      color: const Color(0x0D000000),
      offset: const Offset(0.0, 1.0),
      spreadRadius: 0.0);
  BoxShadow get sm => const BoxShadow(
      blurRadius: 4.0,
      color: const Color(0x14000000),
      offset: const Offset(0.0, 2.0),
      spreadRadius: 0.0);
  BoxShadow get md => const BoxShadow(
      blurRadius: 8.0,
      color: const Color(0x1A000000),
      offset: const Offset(0.0, 4.0),
      spreadRadius: 0.0);
  BoxShadow get lg => const BoxShadow(
      blurRadius: 16.0,
      color: const Color(0x1F000000),
      offset: const Offset(0.0, 8.0),
      spreadRadius: 0.0);
  BoxShadow get xl => const BoxShadow(
      blurRadius: 24.0,
      color: const Color(0x24000000),
      offset: const Offset(0.0, 12.0),
      spreadRadius: 0.0);
  BoxShadow get xxl => const BoxShadow(
      blurRadius: 32.0,
      color: const Color(0x29000000),
      offset: const Offset(0.0, 16.0),
      spreadRadius: 0.0);
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null && fontFamily.isNotEmpty) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
