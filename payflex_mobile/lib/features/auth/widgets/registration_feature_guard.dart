import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Bloque une action réservée aux comptes validés par PayFlex.
void showRegistrationFeatureLockedSnackBar(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '« $featureName » sera disponible après validation de votre inscription par PayFlex.',
        style: GoogleFonts.inter(fontSize: 13),
      ),
      backgroundColor: AppColors.secondary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
