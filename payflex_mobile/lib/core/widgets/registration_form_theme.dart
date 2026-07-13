import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Styles partagés entre inscription client et inscription agent.
class RegistrationFormTheme {
  RegistrationFormTheme._();

  static TextStyle fieldStyle(BuildContext context) =>
      GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500);

  static final _outlineRadius = BorderRadius.circular(12);
  static final _enabledBorderSide = BorderSide(color: Colors.grey.withValues(alpha: 0.35));
  static const _focusedBorderSide = BorderSide(color: AppColors.secondary, width: 1.5);
  static const _errorBorderSide = BorderSide(color: Colors.redAccent);
  static const _errorFocusedBorderSide = BorderSide(color: Colors.redAccent, width: 1.5);

  static InputDecoration _baseOutline({String? labelText, String? hintText, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 14),
      hintText: hintText,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: _outlineRadius, borderSide: _enabledBorderSide),
      enabledBorder: OutlineInputBorder(borderRadius: _outlineRadius, borderSide: _enabledBorderSide),
      focusedBorder: OutlineInputBorder(borderRadius: _outlineRadius, borderSide: _focusedBorderSide),
      errorBorder: OutlineInputBorder(borderRadius: _outlineRadius, borderSide: _errorBorderSide),
      focusedErrorBorder: OutlineInputBorder(borderRadius: _outlineRadius, borderSide: _errorFocusedBorderSide),
      errorStyle: const TextStyle(fontSize: 11, color: Colors.redAccent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static InputDecoration decor(IconData icon, String hint, {Widget? suffix}) {
    return _baseOutline(
      hintText: hint,
      prefix: Icon(icon, color: AppColors.onSurfaceVariant.withValues(alpha: 0.55)),
      suffix: suffix,
    );
  }

  static InputDecoration labeled(String label, {String? hint}) {
    return _baseOutline(labelText: label, hintText: hint);
  }

  static ButtonStyle primaryActionButton({double height = 52}) {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
      minimumSize: Size.fromHeight(height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
    );
  }

  static ButtonStyle secondaryOutlineButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondary,
      side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.35)),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14),
    );
  }

  static Widget sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.secondary,
      ),
    );
  }

  static Widget infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.secondary, height: 1.4),
      ),
    );
  }
}
