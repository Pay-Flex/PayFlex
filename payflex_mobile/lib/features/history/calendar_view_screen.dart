import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/finance_provider.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/responsive_utils.dart';
import 'gap_fill_screen.dart';

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

class CalendarViewScreen extends ConsumerStatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  ConsumerState<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends ConsumerState<CalendarViewScreen> {
  bool _busyCatchUp = false;

  void _prevMonth(int y, int m) {
    if (m <= 1) {
      ref.read(financeProvider.notifier).setCalendarMonth(y - 1, 12);
    } else {
      ref.read(financeProvider.notifier).setCalendarMonth(y, m - 1);
    }
  }

  void _nextMonth(int y, int m) {
    if (m >= 12) {
      ref.read(financeProvider.notifier).setCalendarMonth(y + 1, 1);
    } else {
      ref.read(financeProvider.notifier).setCalendarMonth(y, m + 1);
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _applyCatchUp(BuildContext sheetContext, int y, int m, int day, String paymentMode) async {
    setState(() => _busyCatchUp = true);
    final auth = ref.read(authProvider);
    try {
      final ok = await ref.read(financeProvider.notifier).applyCatchUpForDay(
            year: y,
            month: m,
            day: day,
            paymentMode: paymentMode,
            contributorUserId: auth.userId,
          );
      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible : projet ou cotisation journalière introuvable.',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentMode == 'cash'
                ? 'Rattrapage enregistré : ce jour passe au vert dans votre carnet.'
                : 'Demande envoyée : après validation agent, le jour sera marqué comme respecté.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyCatchUp = false);
    }
  }

  Future<void> _showCotisationDetail(BuildContext context, WidgetRef ref, int day, String status, int year, int month) async {
    final detail = await ref.read(financeProvider.notifier).buildCalendarDayDetail(
          day: day,
          year: year,
          month: month,
          status: status,
        );
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.paddingOf(sheetCtx).bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jour $day — ${_moisFr[month]} $year',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.secondary),
            ),
            const SizedBox(height: 6),
            Text(
              detail.scopeLabel,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 12),
            _detailRow('Statut', detail.statusLabel),
            _detailRow('Anticipé', detail.isAnticipated ? 'Oui' : 'Non'),
            _detailRow(
              'Cotisation journalière',
              detail.dailyAmount > 0 ? formatFcfaLong(detail.dailyAmount) : '—',
            ),
            if (detail.contributionDate != null)
              _detailRow('Date du versement', detail.contributionDate!),
            if (detail.productName != null && detail.productName!.isNotEmpty)
              _detailRow('Article', detail.productName!),
            if (detail.contributionAmount != null)
              _detailRow('Montant versé', formatFcfaLong(detail.contributionAmount!)),
            if (detail.paymentModeLabel != null)
              _detailRow('Mode', detail.paymentModeLabel!),
            if (detail.referenceCode != null)
              _detailRow('Référence', detail.referenceCode!),
            if (detail.coverageNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail.coverageNote,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
              ),
            ],
            const SizedBox(height: 16),
            if (status == 'orange' && detail.dailyAmount > 0) ...[
              Text(
                'Payez une fois la cotisation du jour pour marquer cette date comme respectée dans votre plan.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              if (_busyCatchUp)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _applyCatchUp(sheetCtx, year, month, day, 'mobile_money'),
                        icon: const Icon(Icons.phone_android_rounded, size: 18),
                        label: Text('Mobile Money', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF38A169),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _applyCatchUp(sheetCtx, year, month, day, 'cash'),
                        icon: const Icon(Icons.payments_rounded, size: 18),
                        label: Text('Espèces / immédiat', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: Text('Fermer', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductFilter(FinanceState financeState) {
    final projects = financeState.projects;
    if (projects.length <= 1) return const SizedBox.shrink();

    final selected = financeState.calendarProductFilter;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Tous combinés', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800)),
              selected: selected == null,
              onSelected: (_) => ref.read(financeProvider.notifier).setCalendarProductFilter(null),
            ),
          ),
          ...projects.map((p) {
            final isSelected = selected == p.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  p.title,
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                selected: isSelected,
                onSelected: (_) => ref.read(financeProvider.notifier).setCalendarProductFilter(p.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEstimationCard(FinanceState financeState) {
    if (financeState.projects.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              financeState.calendarScopeLabel.toUpperCase(),
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.secondary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fin estimée', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                      Text(
                        _fmtDate(financeState.estimatedEndDate),
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jours restants', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                      Text(
                        financeState.estimatedDaysRemaining > 0 ? '${financeState.estimatedDaysRemaining} j' : 'Objectif atteint',
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);
    final y = financeState.calendarViewYear;
    final m = financeState.calendarViewMonth;
    final lastDay = DateTime(y, m + 1, 0).day;
    final leading = DateTime(y, m, 1).weekday - 1;
    final totalCells = leading + lastDay;

    final gapCount = financeState.calendarStatuses.values.where((s) => s == 'orange').length;

    // Padding horizontal adaptatif : sur les petits écrans (320px) on réduit la
    // marge pour agrandir au maximum les cases du calendrier (cibles tactiles).
    final hPad = context.responsiveHPadding(max: 32, min: 12);

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: gapCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GapFillScreen()),
              ),
              backgroundColor: AppColors.warning,
              icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.white),
              label: Text(
                'Combler les trous ($gapCount)',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'SUIVI DES COTISATIONS',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 14,
            color: AppColors.secondary,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 100,
            right: -100,
            child: _buildCalendarBlob(AppColors.primary, 300),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).move(
                duration: 10.seconds,
                begin: const Offset(-20, -20),
                end: const Offset(20, 20),
              ),
          Positioned(
            bottom: 200,
            left: -150,
            child: _buildCalendarBlob(AppColors.secondary, 400),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).move(
                duration: 15.seconds,
                begin: const Offset(30, 30),
                end: const Offset(-30, -30),
              ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _buildEstimationCard(financeState),
                _buildProductFilter(financeState),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _prevMonth(y, m),
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.secondary),
                        ),
                        Text(
                          '${_moisFr[m]} $y'.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.secondary,
                            letterSpacing: 1,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _nextMonth(y, m),
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),
                SizedBox(
                  height: 52,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 12,
                    itemBuilder: (context, i) {
                      final month = i + 1;
                      final selected = month == m;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Center(
                          child: ChoiceChip(
                            label: Text(
                              _moisFr[month].substring(0, 3),
                              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            selected: selected,
                            onSelected: (_) => ref.read(financeProvider.notifier).setCalendarMonth(y, month),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM']
                        .map((day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.secondary.withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < leading) {
                      return const SizedBox.shrink();
                    }
                    final day = index - leading + 1;
                    final statusString = financeState.calendarStatuses[day] ?? 'gris';

                    final today = DateTime.now();
                    final todayDate = DateTime(today.year, today.month, today.day);
                    final cellDate = DateTime(y, m, day);
                    final isPast = cellDate.isBefore(todayDate);
                    final isUnpaidPast = statusString == 'gris' && isPast;
                    final isNeutralFuture = statusString == 'gris' && !isPast;

                    final Color statusColor = switch (statusString) {
                      'vert' => AppColors.success,
                      'orange' => AppColors.warning,
                      'bleu' => AppColors.info,
                      'gris' => isUnpaidPast ? AppColors.error : Colors.transparent,
                      _ => Colors.transparent,
                    };

                    final isToday =
                        today.year == y && today.month == m && day == today.day;

                    return GestureDetector(
                      onTap: () => _showCotisationDetail(context, ref, day, statusString, y, m),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : (isUnpaidPast
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : (isNeutralFuture ? Colors.grey.shade100 : Colors.white)),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isToday
                                ? AppColors.primary
                                : (isUnpaidPast
                                    ? AppColors.error.withValues(alpha: 0.25)
                                    : AppColors.secondary.withValues(alpha: 0.05)),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '$day',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w900,
                                  color: isUnpaidPast ? AppColors.error : AppColors.secondary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (statusColor != Colors.transparent)
                              Positioned(
                                bottom: 5,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (index * 12).ms).scale(begin: const Offset(0.8, 0.8));
                  },
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 8),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        _legendItem(AppColors.error, 'Non payé', 'Jour passé sans cotisation enregistrée.'),
                        const SizedBox(height: 16),
                        _legendItem(AppColors.success, 'Plan respecté', 'Vos cotisations sont à jour pour cette date.'),
                        const SizedBox(height: 16),
                        _legendItem(AppColors.info, 'En avance', 'Une partie de votre épargne couvre des jours futurs.'),
                        const SizedBox(height: 16),
                        _legendItem(AppColors.warning, 'Rattrapage', 'Date passée non couverte — vous pouvez payer ce jour.'),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String title, String desc) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 13)),
              Text(desc,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
