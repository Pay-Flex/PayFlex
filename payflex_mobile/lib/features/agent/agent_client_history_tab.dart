import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/agent_client_finance_provider.dart';
import '../payment/contribution_receipt_screen.dart';

/// Historique cotisations client — mêmes filtres que l'app client.
class AgentClientHistoryTab extends ConsumerStatefulWidget {
  final int clientUserId;

  const AgentClientHistoryTab({super.key, required this.clientUserId});

  @override
  ConsumerState<AgentClientHistoryTab> createState() => _AgentClientHistoryTabState();
}

class _AgentClientHistoryTabState extends ConsumerState<AgentClientHistoryTab> {
  String _filter = 'all';

  String _statusFr(String s) => switch (s) {
        'validated' => 'Validé',
        'pending' => 'En attente',
        'rejected' => 'Refusé',
        _ => s,
      };

  String _modeFr(String? m) => switch (m) {
        'cash' => 'Espèces',
        'mobile_money' => 'Mobile money',
        _ => m ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    final fin = watchAgentClientFinance(ref, widget.clientUserId);
    if (fin.loading) return const Center(child: CircularProgressIndicator());

    final raw = fin.detail?['contributions'] is List ? fin.detail!['contributions'] as List : <dynamic>[];
    final items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((c) {
      if (_filter == 'all') return true;
      return (c['status']?.toString() ?? '') == _filter;
    }).toList();

    final total = items.fold<double>(0, (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip('Tous', 'all'),
              _chip('Validés', 'validated'),
              _chip('En attente', 'pending'),
              _chip('Refusés', 'rejected'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('${items.length} opération(s) — ${total.toInt()} FCFA', style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 12)),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('Aucune cotisation', style: GoogleFonts.manrope(color: Colors.grey)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final amount = (c['amount'] as num?)?.toDouble() ?? 0;
                    final status = c['status']?.toString() ?? '';
                    final when = (c['paid_at'] ?? c['created_at'])?.toString() ?? '';
                    final product = c['product_name']?.toString() ?? 'Cotisation';
                    final mode = c['payment_mode']?.toString();
                    final id = c['id']?.toString() ?? '';
                    final catchY = c['catchup_year'];
                    final catchM = c['catchup_month'];
                    final catchD = c['catchup_day'];
                    String? catchupLabel;
                    if (catchY is num && catchM is num && catchD is num) {
                      catchupLabel = 'Rattrapage ${catchD.toInt()}/${catchM.toInt()}/${catchY.toInt()}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${amount.toInt()} FCFA', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$product · ${_statusFr(status)}', style: GoogleFonts.inter(fontSize: 11)),
                            Text('${when.split('T').first} · ${_modeFr(mode)}', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                            if (catchupLabel != null) Text(catchupLabel, style: GoogleFonts.inter(fontSize: 10, color: AppColors.warning)),
                          ],
                        ),
                        trailing: const Icon(Icons.receipt_long_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContributionReceiptScreen(
                              amount: amount,
                              reference: id,
                              paidAt: DateTime.tryParse(when) ?? DateTime.now(),
                              paymentModeLabel: _modeFr(mode),
                              slotsCount: 1,
                              awaitingValidation: status == 'pending',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700)),
        selected: sel,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}
