import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

/// Bandeau simple et lisible affiché lorsque les données proviennent du cache
/// local (SQLite) parce que le serveur PayFlex est injoignable.
///
/// Message volontairement court et en français pour tous les profils :
/// « Pas de connexion — données enregistrées ».
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'Pas de connexion — données enregistrées',
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final String message;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0B44B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 22, color: Color(0xFFB7791F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
