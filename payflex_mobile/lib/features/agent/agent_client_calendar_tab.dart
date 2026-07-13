import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/agent_client_finance_provider.dart';

const _moisFr = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

/// Carnet cotisations — même vue que l'app client, en lecture agent.
class AgentClientCalendarTab extends ConsumerWidget {
  final int clientUserId;
  final VoidCallback? onCollectCatchup;

  const AgentClientCalendarTab({
    super.key,
    required this.clientUserId,
    this.onCollectCatchup,
  });

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _showDayDetail(BuildContext context, WidgetRef ref, int day, String status, int y, int m) async {
    final detail = await ref.read(agentClientFinanceProvider.notifier).buildCalendarDayDetail(
          day: day,
          year: y,
          month: m,
          status: status,
        );
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.paddingOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jour $day — ${_moisFr[m]} $y', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(detail.scopeLabel, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Text('Statut : ${detail.statusLabel}', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            Text('Anticipé : ${detail.isAnticipated ? 'Oui' : 'Non'}', style: GoogleFonts.inter(fontSize: 13)),
            if (detail.dailyAmount > 0) Text('Cotisation : ${detail.dailyAmount.toInt()} FCFA/j', style: GoogleFonts.inter(fontSize: 13)),
            if (detail.contributionDate != null) Text('Versement : ${detail.contributionDate}', style: GoogleFonts.inter(fontSize: 13)),
            if (detail.coverageNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail.coverageNote, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
            ],
            if (status == 'orange' && onCollectCatchup != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onCollectCatchup!();
                  },
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Collecter le rattrapage'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = watchAgentClientFinance(ref, clientUserId);
    if (fin.loading) return const Center(child: CircularProgressIndicator());
    if (!fin.hasData) {
      return Center(child: Text('Aucune donnée carnet', style: GoogleFonts.manrope(color: Colors.grey)));
    }

    final y = fin.calendarViewYear;
    final m = fin.calendarViewMonth;
    final lastDay = DateTime(y, m + 1, 0).day;
    final leading = DateTime(y, m, 1).weekday - 1;
    final totalCells = leading + lastDay;
    final gapCount = fin.calendarStatuses.values.where((s) => s == 'orange').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gapCount > 0 && onCollectCatchup != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: Material(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.auto_fix_high_rounded, color: AppColors.warning),
                title: Text('$gapCount jour(s) à rattraper', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13)),
                trailing: TextButton(onPressed: onCollectCatchup, child: const Text('Collecter')),
              ),
            ),
          ),
        _estimationCard(fin),
        if (fin.projects.length > 1) _productFilter(ref, fin),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                if (m <= 1) {
                  ref.read(agentClientFinanceProvider.notifier).setCalendarMonth(y - 1, 12);
                } else {
                  ref.read(agentClientFinanceProvider.notifier).setCalendarMonth(y, m - 1);
                }
              },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('${_moisFr[m]} $y'.toUpperCase(), style: GoogleFonts.manrope(fontWeight: FontWeight.w900)),
            IconButton(
              onPressed: () {
                if (m >= 12) {
                  ref.read(agentClientFinanceProvider.notifier).setCalendarMonth(y + 1, 1);
                } else {
                  ref.read(agentClientFinanceProvider.notifier).setCalendarMonth(y, m + 1);
                }
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM']
                .map((d) => Text(d, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey)))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              final status = fin.calendarStatuses[day] ?? 'gris';
              final color = switch (status) {
                'vert' => AppColors.success,
                'orange' => AppColors.warning,
                'bleu' => AppColors.info,
                _ => Colors.transparent,
              };
              final today = DateTime.now();
              final isToday = today.year == y && today.month == m && day == today.day;
              return GestureDetector(
                onTap: () => _showDayDetail(context, ref, day, status, y, m),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary.withValues(alpha: 0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12)),
                      if (color != Colors.transparent)
                        Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _legend(),
      ],
    );
  }

  Widget _estimationCard(AgentClientFinanceState fin) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fin estimée', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
            Text(_fmtDate(fin.estimatedEndDate), style: GoogleFonts.manrope(fontWeight: FontWeight.w900)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Jours restants', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
            Text(fin.estimatedDaysRemaining > 0 ? '${fin.estimatedDaysRemaining} j' : 'Atteint', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.primary)),
          ])),
        ],
      ),
    );
  }

  Widget _productFilter(WidgetRef ref, AgentClientFinanceState fin) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Tous', style: TextStyle(fontSize: 10)),
              selected: fin.calendarProductFilter == null,
              onSelected: (_) => ref.read(agentClientFinanceProvider.notifier).setCalendarProductFilter(null),
            ),
          ),
          ...fin.projects.map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(p.title, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                  selected: fin.calendarProductFilter == p.id,
                  onSelected: (_) => ref.read(agentClientFinanceProvider.notifier).setCalendarProductFilter(p.id),
                ),
              )),
        ],
      ),
    );
  }

  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _leg(AppColors.success, 'À jour'),
          _leg(AppColors.warning, 'Rattrapage'),
          _leg(AppColors.info, 'Anticipé'),
          _leg(Colors.grey.shade400, 'Non payé'),
        ],
      ),
    );
  }

  Widget _leg(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10)),
        ],
      );
}
