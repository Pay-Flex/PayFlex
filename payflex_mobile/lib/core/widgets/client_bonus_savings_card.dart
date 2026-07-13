import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../finance/client_bonus_savings_logic.dart';

/// Carte épargne bonus PayFlex (part client du jour « hors plan officiel »).
class ClientBonusSavingsCard extends StatelessWidget {
  final BonusSavingsSummary summary;
  final bool compact;
  /// Vue agent : libellé « pour le client » au lieu de « pour vous ».
  final bool forAgent;

  const ClientBonusSavingsCard({
    super.key,
    required this.summary,
    this.compact = false,
    this.forAgent = false,
  });

  String _fcfa(num v) => '${v.round()} FCFA';

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) return const SizedBox.shrink();

    final now = DateTime.now();
    final officialDays = summary.officialDaysThisMonth > 0
        ? summary.officialDaysThisMonth
        : ClientBonusSavingsLogic.officialDaysInMonth(now.year, now.month);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F766E).withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.savings_outlined, color: Color(0xFF0F766E), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÉPARGNE BONUS PAYFLEX',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    Text(
                      forAgent
                          ? 'Part client : cotisation du jour ÷ 2 ($officialDays j. officiels / mois)'
                          : 'Votre part : cotisation du jour ÷ 2 ($officialDays j. officiels / mois)',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Total épargné',
                  _fcfa(summary.accruedFcfa),
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  '+ Ce mois',
                  _fcfa(summary.monthlyFcfa),
                  AppColors.primary,
                ),
              ),
            ],
          ),
          if (!compact && summary.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...summary.lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· ${l.productName} ×${l.quantity} → ${_fcfa(l.monthlyBonus)}/mois',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
          if (summary.activeMonths > 0 || summary.dailyContribution > 0) ...[
            const SizedBox(height: 8),
            Text(
              summary.activeMonths > 0
                  ? '${summary.activeMonths} mois crédité${summary.activeMonths > 1 ? 's' : ''} en base · cotisation ${_fcfa(summary.dailyContribution)}/jour'
                  : 'Cotisation ${_fcfa(summary.dailyContribution)}/jour',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
            ),
            if (summary.creditedInDatabase && summary.lastCreditedYearMonth != null)
              Text(
                'Dernier crédit : ${summary.lastCreditedYearMonth}',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(fontSize: compact ? 15 : 17, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}
