import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/agent_provider.dart';
import 'agent_client_detail_screen.dart';

class AgentRegistryScreen extends ConsumerWidget {
  const AgentRegistryScreen({super.key});

  String _formatWhen(dynamic raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw.toString().replaceFirst(' ', 'T'));
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'validated':
        return const Color(0xFF22C55E);
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'validated':
        return 'Validée';
      case 'pending':
        return 'En attente';
      case 'rejected':
        return 'Refusée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentDataProvider);
    final items = agent.registry;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Registre des collectes', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => ref.read(agentDataProvider.notifier).refresh(silent: false),
            icon: agent.isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: AppColors.secondary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(agentDataProvider.notifier).refresh(silent: false),
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Aucune collecte enregistrée', style: GoogleFonts.manrope(color: Colors.grey, fontWeight: FontWeight.w600))),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  final status = c['status']?.toString() ?? '';
                  final amount = (c['amount'] as num?)?.toInt() ?? 0;
                  final clientName = c['client_name']?.toString() ?? 'Client';
                  final product = c['product_name']?.toString() ?? 'Cotisation';
                  final clientId = (c['client_id'] as num?)?.toInt();
                  final isCatchup = c['catchup_day'] != null;

                  return InkWell(
                    onTap: clientId == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AgentClientDetailScreen(
                                  clientId: clientId,
                                  name: clientName,
                                  zone: '',
                                ),
                              ),
                            ),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 48,
                            decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(6)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(clientName, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)),
                                Text(product, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(_statusLabel(status), style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor(status))),
                                    ),
                                    if (isCatchup) ...[
                                      const SizedBox(width: 6),
                                      Text('Rattrapage', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                                    ],
                                  ],
                                ),
                                Text(_formatWhen(c['when_at']), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('+$amount F', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: const Color(0xFF22C55E))),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
