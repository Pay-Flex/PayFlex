import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/allocation_result.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
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
  final _api = MobileApiService();

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
                      final isAllocated = t.allocationGroupId != null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text('${t.amount.toInt()} FCFA', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                              if (isAllocated) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Répartition auto',
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${t.date.split('T').first} — ${_statusFr(t.status)}',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => isAllocated
                              ? _showAllocationDetail(context, t.allocationGroupId!)
                              : Navigator.push(
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

  Future<void> _showAllocationDetail(BuildContext context, int groupId) async {
    final auth = ref.read(authProvider);
    final userId = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (userId == null || phone == null || pin == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FutureBuilder<Map<String, dynamic>?>(
        future: _api.fetchAllocationGroup(userId: userId, phone: phone, pin: pin, groupId: groupId),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final lines = (data?['allocations'] as List? ?? [])
              .whereType<Map>()
              .map((e) => AllocationLine.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          final allocation = data == null || lines.isEmpty
              ? null
              : AllocationResult(
                  sourceAmountFcfa: (data['sourceAmountFcfa'] as num?)?.toDouble() ?? 0,
                  lines: lines,
                  unallocatedSurplusFcfa: (data['unallocatedSurplusFcfa'] as num?)?.toDouble() ?? 0,
                );
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.call_split_rounded, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('Répartition du paiement', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (allocation == null || allocation.lines.isEmpty)
                    Text(
                      'Détail indisponible pour le moment.',
                      style: GoogleFonts.inter(color: Colors.grey.shade600),
                    )
                  else
                    Text(
                      allocation.toFrenchMessage(),
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
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
