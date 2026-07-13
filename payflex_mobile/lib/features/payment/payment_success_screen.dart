import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/money_format.dart';

/// Écran de confirmation de paiement volontairement grand et simple.
///
/// Objectif accessibilité : une grande coche verte, le montant lisible
/// (« 25 000 F »), un message court et un seul gros bouton « OK ». Un lien
/// discret « Voir le reçu » reste disponible sans surcharger l'écran.
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.awaitingAgentValidation,
    required this.paymentModeLabel,
    required this.slotsCount,
    this.fedapayConfirmed = false,
    this.productName,
    this.onViewReceipt,
    required this.onDone,
  });

  final double amount;
  final bool awaitingAgentValidation;
  final bool fedapayConfirmed;
  final String paymentModeLabel;
  final int slotsCount;
  final String? productName;
  final VoidCallback? onViewReceipt;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        awaitingAgentValidation ? const Color(0xFFB7791F) : const Color(0xFF38A169);
    final Color bg = awaitingAgentValidation ? const Color(0xFFFFF8E6) : const Color(0xFFF0FFF4);
    final IconData icon =
        awaitingAgentValidation ? Icons.hourglass_top_rounded : Icons.check_rounded;

    final String title = awaitingAgentValidation
        ? 'Demande envoyée'
        : (fedapayConfirmed ? 'Paiement confirmé' : 'Cotisation validée');

    final String message = awaitingAgentValidation
        ? 'Votre cotisation sera ajoutée à votre carnet après validation par votre agent.'
        : 'C\'est fait ! Votre carnet est à jour.';

    final slots = slotsCount > 0 ? slotsCount : 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              children: [
                const Spacer(),
                // Grande coche visuelle
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, color: accent, size: 88),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.manrope(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 14),
                // Montant en très grand, format FCFA lisible « 25 000 F »
                Text(
                  formatFcfa(amount),
                  textAlign: TextAlign.center,
                  style: AppTypography.manrope(
                    fontWeight: FontWeight.w900,
                    fontSize: 46,
                    color: accent,
                    height: 1.0,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 8),
                if (productName != null && productName!.trim().isNotEmpty) ...[
                  Text(
                    productName!.trim(),
                    textAlign: TextAlign.center,
                    style: AppTypography.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.secondary.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.inter(
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.secondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '$slots jour${slots > 1 ? 's' : ''} de plan · $paymentModeLabel',
                    textAlign: TextAlign.center,
                    style: AppTypography.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const Spacer(),
                // Un seul gros bouton principal
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'OK',
                      style: AppTypography.manrope(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
                    ),
                  ),
                ),
                if (onViewReceipt != null)
                  TextButton(
                    onPressed: onViewReceipt,
                    child: Text(
                      'Voir le reçu',
                      style: AppTypography.manrope(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
