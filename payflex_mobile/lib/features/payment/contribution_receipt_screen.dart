import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// Reçu de cotisation consultable (spec PDF phase 1.2).
class ContributionReceiptScreen extends StatelessWidget {
  final double amount;
  final String reference;
  final DateTime paidAt;
  final String paymentModeLabel;
  final int slotsCount;
  final bool awaitingValidation;

  const ContributionReceiptScreen({
    super.key,
    required this.amount,
    required this.reference,
    required this.paidAt,
    required this.paymentModeLabel,
    required this.slotsCount,
    this.awaitingValidation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Reçu de cotisation', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(
                  awaitingValidation ? Icons.hourglass_top_rounded : Icons.receipt_long_rounded,
                  size: 48,
                  color: awaitingValidation ? AppColors.warning : AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${amount.toInt()} FCFA',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 28, color: AppColors.secondary),
                ),
              ),
              const SizedBox(height: 20),
              _row('Référence', reference),
              _row('Date', '${paidAt.day}/${paidAt.month}/${paidAt.year} ${paidAt.hour}:${paidAt.minute.toString().padLeft(2, '0')}'),
              _row('Mode', paymentModeLabel),
              _row('Jours de plan', slotsCount > 0 ? '$slotsCount' : '1'),
              _row('Statut', awaitingValidation ? 'En attente validation agent' : 'Validé'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(k, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600))),
            Expanded(child: Text(v, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13))),
          ],
        ),
      );
}
