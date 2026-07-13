import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/finance_provider.dart';
import '../payment/contribution_receipt_screen.dart';

/// Historique des cotisations avec filtres (spec PDF phase 5.4).
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(financeProvider).transactions;
    final filtered = txs.where((t) {
      if (_statusFilter == 'all') return true;
      return t.status == _statusFilter;
    }).toList();

    final total = filtered.fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Historique', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
            padding: const EdgeInsets.all(16),
            child: Text(
              '${filtered.length} opération(s) — ${total.toInt()} FCFA',
              style: GoogleFonts.inter(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('Aucune cotisation', style: GoogleFonts.manrope(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${t.amount.toInt()} FCFA', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            '${t.date.split('T').first} — ${_statusFr(t.status)}',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContributionReceiptScreen(
                                amount: t.amount,
                                reference: t.id,
                                paidAt: DateTime.tryParse(t.date) ?? DateTime.now(),
                                paymentModeLabel: t.title,
                                slotsCount: 1,
                                awaitingValidation: t.status == 'pending',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _statusFr(String s) => switch (s) {
        'validated' => 'Validé',
        'pending' => 'En attente',
        'rejected' => 'Refusé',
        _ => s,
      };

  Widget _chip(String label, String value) {
    final sel = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700)),
        selected: sel,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }
}
