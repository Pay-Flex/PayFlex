import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/allocation_result.dart';
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
    this.gatewayConfirmed = false,
    this.productName,
    this.allocation,
    this.onViewReceipt,
    required this.onDone,
  });

  final double amount;
  final bool awaitingAgentValidation;
  final bool gatewayConfirmed;
  final String paymentModeLabel;
  final int slotsCount;
  final String? productName;

  /// Détail de la répartition automatique si le paiement a dépassé le reste à
  /// payer du produit visé et a été scindé entre plusieurs produits actifs.
  final AllocationResult? allocation;
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
        : (gatewayConfirmed ? 'Paiement confirmé' : 'Cotisation validée');

    final splitNow = allocation != null && allocation!.wasSplit;
    final String message = awaitingAgentValidation
        ? 'Votre cotisation sera ajoutée à votre carnet après validation par votre agent.'
        : splitNow
            ? allocation!.toFrenchMessage()
            : 'C\'est fait ! Votre carnet est à jour.';

    final slots = slotsCount > 0 ? slotsCount : 1;
    final split = splitNow;

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
                if (!split && productName != null && productName!.trim().isNotEmpty) ...[
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
                if (split) ...[
                  const SizedBox(height: 16),
                  _AllocationBreakdownCard(allocation: allocation!),
                ],
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

/// Carte récapitulant la répartition automatique d'un paiement scindé entre
/// plusieurs produits (ex. « 200 F → Produit A · objectif atteint, 300 F → Produit B »).
class _AllocationBreakdownCard extends StatelessWidget {
  const _AllocationBreakdownCard({required this.allocation});

  final AllocationResult allocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_split_rounded, size: 16, color: AppColors.secondary.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'RÉPARTITION AUTOMATIQUE',
                style: AppTypography.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.secondary.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in allocation.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.productName,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.manrope(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.secondary),
                    ),
                  ),
                  if (line.goalReachedNow)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.check_circle_rounded, size: 15, color: const Color(0xFF38A169).withValues(alpha: 0.8)),
                    ),
                  Text(
                    formatFcfa(line.amountFcfa),
                    style: AppTypography.manrope(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          if (allocation.unallocatedSurplusFcfa > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${formatFcfa(allocation.unallocatedSurplusFcfa)} en attente d’affectation — contactez votre agent.',
              style: AppTypography.inter(fontSize: 11, color: Colors.orange.shade800, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
