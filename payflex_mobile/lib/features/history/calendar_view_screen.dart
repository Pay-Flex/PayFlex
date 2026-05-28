import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  void _showCotisationDetail(BuildContext context, WidgetRef ref, int day, String status, int year, int month) {
    final financeState = ref.read(financeProvider);
    final proj = financeState.calendarActiveProject;

    final statusLabel = switch (status) {
      'vert' => 'À jour',
      'orange' => 'Rattrapage',
      'bleu' => 'Anticipé',
      _ => 'À venir',
    };

    final daily = proj?.dailySuggested ?? 0;

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
            const SizedBox(height: 10),
            Text('Statut : $statusLabel', style: GoogleFonts.inter(color: AppColors.secondary.withOpacity(0.75))),
            const SizedBox(height: 8),
            Text(
              proj != null ? 'Cotisation journalière du projet : ${daily.toStringAsFixed(0)} FCFA' : 'Aucun projet actif.',
              style: GoogleFonts.inter(color: AppColors.secondary.withOpacity(0.75)),
            ),
            const SizedBox(height: 16),
            if (status == 'orange' && proj != null && daily > 0) ...[
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
                const SizedBox(height: 8),
                Text(
                  '« Immédiat » crédite tout de suite le carnet et le jour devient vert. Mobile Money reste orange jusqu’à validation par l’agent.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
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

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);
    final y = financeState.calendarViewYear;
    final m = financeState.calendarViewMonth;
    final lastDay = DateTime(y, m + 1, 0).day;
    final leading = DateTime(y, m, 1).weekday - 1;
    final totalCells = leading + lastDay;

    return Scaffold(
      backgroundColor: Colors.white,
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.03),
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM']
                      .map((day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: GoogleFonts.manrope(
                                  color: AppColors.secondary.withOpacity(0.3),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < leading) {
                      return const SizedBox.shrink();
                    }
                    final day = index - leading + 1;
                    final statusString = financeState.calendarStatuses[day] ?? 'gris';
                    final Color statusColor = switch (statusString) {
                      'vert' => AppColors.success,
                      'orange' => AppColors.warning,
                      'bleu' => AppColors.info,
                      _ => Colors.transparent,
                    };

                    final today = DateTime.now();
                    final isToday =
                        today.year == y && today.month == m && day == today.day;

                    return GestureDetector(
                      onTap: () => _showCotisationDetail(context, ref, day, statusString, y, m),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isToday ? AppColors.primary : AppColors.secondary.withOpacity(0.05),
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
                                  color: AppColors.secondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (statusColor != Colors.transparent)
                              Positioned(
                                bottom: 6,
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
                                        BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4),
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: AppColors.secondary.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _legendItem(AppColors.success, 'Plan respecté', 'Vos cotisations sont à jour pour cette date.'),
                      const SizedBox(height: 16),
                      _legendItem(AppColors.info, 'En avance', 'Une partie de votre épargne couvre des jours futurs.'),
                      const SizedBox(height: 16),
                      _legendItem(AppColors.warning, 'Rattrapage', 'Date passée non couverte — vous pouvez payer ce jour.'),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
              const SizedBox(height: 100),
            ],
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
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
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
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary.withOpacity(0.5))),
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
        color: color.withOpacity(0.03),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
