import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/finance_provider.dart';

const _moisFr = [
  '',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

/// Écran « Combler les trous » — rattrapage groupé des jours orange (spec PDF).
class GapFillScreen extends ConsumerStatefulWidget {
  const GapFillScreen({super.key});

  @override
  ConsumerState<GapFillScreen> createState() => _GapFillScreenState();
}

class _GapFillScreenState extends ConsumerState<GapFillScreen> {
  bool _busy = false;
  String _paymentMode = 'cash';

  List<int> _orangeDays(FinanceState fin) {
    return fin.calendarStatuses.entries
        .where((e) => e.value == 'orange')
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  Future<void> _payAll() async {
    final fin = ref.read(financeProvider);
    final days = _orangeDays(fin);
    if (days.isEmpty) return;
    setState(() => _busy = true);
    final auth = ref.read(authProvider);
    var ok = 0;
    for (final day in days) {
      final success = await ref.read(financeProvider.notifier).applyCatchUpForDay(
            year: fin.calendarViewYear,
            month: fin.calendarViewMonth,
            day: day,
            paymentMode: _paymentMode,
            contributorUserId: auth.userId,
          );
      if (success) ok++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok > 0
              ? '$ok jour(s) traité(s). Consultez votre carnet.'
              : 'Aucun rattrapage enregistré.',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
    );
    if (ok > 0) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fin = ref.watch(financeProvider);
    final days = _orangeDays(fin);
    final daily = fin.calendarActiveProject?.dailySuggested ?? 0;
    final total = days.length * daily;

    return Scaffold(
      appBar: AppBar(
        title: Text('Combler les trous', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${_moisFr[fin.calendarViewMonth]} ${fin.calendarViewYear}',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            days.isEmpty
                ? 'Aucun jour en rattrapage sur ce mois.'
                : '${days.length} jour(s) à régulariser — ${total.toInt()} FCFA estimés.',
            style: GoogleFonts.inter(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          if (days.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days
                  .map(
                    (d) => Chip(
                      label: Text('Jour $d', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                      backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('Mode de paiement', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Espèces')),
                ButtonSegment(value: 'mobile_money', label: Text('Mobile Money')),
              ],
              selected: {_paymentMode},
              onSelectionChanged: (s) => setState(() => _paymentMode = s.first),
            ),
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: _payAll,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  'Régulariser ${days.length} jour(s)',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
