import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Polices : Google Fonts en debug, polices système en release APK (pas de téléchargement réseau).
class AppTypography {
  AppTypography._();

  static TextTheme textTheme({Brightness brightness = Brightness.light}) {
    if (kReleaseMode) {
      return _systemTextTheme(brightness);
    }
    final base = brightness == Brightness.dark
        ? GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.manropeTextTheme();
    return base.copyWith(
      displaySmall: manrope(fontWeight: FontWeight.w900, color: _titleColor(brightness)),
      headlineMedium: manrope(fontWeight: FontWeight.w800, color: _titleColor(brightness)),
      bodyLarge: inter(fontSize: 16, color: _bodyColor(brightness)),
      bodyMedium: inter(fontSize: 14, color: _bodyMutedColor(brightness)),
    );
  }

  static TextStyle manrope({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    if (kReleaseMode) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    }
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    if (kReleaseMode) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  static TextTheme _systemTextTheme(Brightness brightness) {
    final title = _titleColor(brightness);
    final body = _bodyColor(brightness);
    final muted = _bodyMutedColor(brightness);
    return TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w900, color: title),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: title),
      bodyLarge: TextStyle(fontSize: 16, color: body),
      bodyMedium: TextStyle(fontSize: 14, color: muted),
    );
  }

  static Color _titleColor(Brightness brightness) =>
      brightness == Brightness.dark ? Colors.white : AppColors.secondary;

  static Color _bodyColor(Brightness brightness) =>
      brightness == Brightness.dark ? AppColors.darkOnSurface : AppColors.onSurface;

  static Color _bodyMutedColor(Brightness brightness) =>
      brightness == Brightness.dark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
}
