import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/client_bonus_savings_card.dart';
import '../../core/finance/client_bonus_savings_logic.dart';

/// Ce que le client voit sur son smartphone PayFlex (synthèse pour l'agent).
class AgentClientSmartphoneTab extends StatelessWidget {
  final Map<String, dynamic>? detail;

  const AgentClientSmartphoneTab({super.key, required this.detail});

  String _fcfa(num? v) => v == null ? '—' : '${v.toInt()} FCFA';

  String _statusLabel(String? s) => switch (s) {
        'adhere' => 'Adhérent actif',
        'valide' => 'En attente d\'adhésion',
        'pending' => 'Compte en validation',
        _ => s ?? '—',
      };

  String _deliveryLabel(String? s) => switch (s) {
        'goal_reached' => 'Objectif atteint — clôture en cours',
        'awaiting_closure' => 'En attente de clôture centre',
        'ready_for_pickup' => 'Prêt pour livraison',
        'delivered' => 'Équipement livré',
        _ => s != null && s.isNotEmpty ? s : 'En cours d\'épargne',
      };

  @override
  Widget build(BuildContext context) {
    if (detail == null || detail!['hasData'] != true) {
      return Center(child: Text('Client sans application', style: GoogleFonts.manrope(color: Colors.grey)));
    }

    final d = detail!;
    final daily = (d['dailyContributionFcfa'] as num?)?.toDouble() ?? 0;
    final bonusRaw = d['bonusSavings'];
    final bonus = bonusRaw is Map ? BonusSavingsSummary.fromMap(Map<String, dynamic>.from(bonusRaw)) : BonusSavingsSummary(monthlyFcfa: ClientBonusSavingsLogic.monthlyClientBonus(daily), dailyContribution: daily);
    final hasPhone = d['hasSmartphone'] == true || (d['phone']?.toString().trim().isNotEmpty ?? false);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _card(
          icon: Icons.smartphone_rounded,
          title: 'Application client',
          child: Text(
            hasPhone
                ? 'Ce client dispose d\'un téléphone et peut utiliser l\'app PayFlex (accueil, catalogue, paiement, suivi carnet, historique).'
                : 'Pas de téléphone renseigné — suivi principalement via l\'agent terrain.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.badge_outlined,
          title: 'Identité dossier',
          child: Column(
            children: [
              _row('Code dossier', d['uniqueCode']?.toString() ?? '—'),
              _row('Téléphone', d['phone']?.toString() ?? '—'),
              _row('Ville', d['city']?.toString() ?? '—'),
              _row('Profession', d['profession']?.toString() ?? '—'),
              _row('Statut', _statusLabel(d['status']?.toString())),
              _row('Adhésion 250 F', d['adhesionFeePaid'] == true ? 'Payée' : 'Non payée'),
              _row('Gestion', d['selfManaged'] == true ? 'Autonome (smartphone)' : 'Avec agent'),
              _row('Assiduité', d['assiduityBadge']?.toString() ?? 'standard'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Vue accueil client',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Solde épargné : ${_fcfa(d['collectedFcfa'] as num?)}', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
              Text('Objectif : ${_fcfa(d['totalProjectFcfa'] as num?)}', style: GoogleFonts.inter(fontSize: 12)),
              Text('Cotisation : ${daily.toInt()} F / jour', style: GoogleFonts.inter(fontSize: 12)),
              Text('Rattrapages : ${d['catchupPendingDays'] ?? 0} jour(s)', style: GoogleFonts.inter(fontSize: 12)),
              if (d['lastPaymentAt'] != null)
                Text('Dernier versement : ${d['lastPaymentAt']} (${_fcfa(d['lastPaymentAmount'] as num?)})', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
            ],
          ),
        ),
        if (bonus.hasData) ...[
          const SizedBox(height: 10),
          ClientBonusSavingsCard(summary: bonus, compact: true, forAgent: true),
        ],
        const SizedBox(height: 10),
        _card(
          icon: Icons.local_shipping_outlined,
          title: 'Livraison (vue client)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_deliveryLabel(d['deliveryStatus']?.toString()), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              if (d['deliveryProductName'] != null) Text('Article : ${d['deliveryProductName']}', style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.visibility_outlined,
          title: 'Onglets app client',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _feature(Icons.home_rounded, 'Accueil', 'Solde, projets, livraison, épargne bonus'),
              _feature(Icons.grid_view_rounded, 'Catalogue', 'Articles et panier'),
              _feature(Icons.account_balance_wallet_rounded, 'Paiement', 'Cotisation mobile money / FedaPay'),
              _feature(Icons.calendar_today_rounded, 'Suivi', 'Carnet calendrier + estimation'),
              _feature(Icons.history_rounded, 'Historique', 'Filtres et reçus'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required IconData icon, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey))),
          Expanded(child: Text(value, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12)),
                Text(desc, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
