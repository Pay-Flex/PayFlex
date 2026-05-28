import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';

/// Détail d’un projet d’épargne local (table `projects` + cotisations associées).
class DashboardProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const DashboardProjectDetailScreen({super.key, required this.projectId});

  @override
  State<DashboardProjectDetailScreen> createState() => _DashboardProjectDetailScreenState();
}

class _DashboardProjectDetailScreenState extends State<DashboardProjectDetailScreen> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _tx = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _db.getProjectById(widget.projectId);
    final t = await _db.getTransactionsForProject(widget.projectId);
    if (!mounted) return;
    setState(() {
      _project = p;
      _tx = t;
      _loading = false;
    });
  }

  String _fmt(num v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Projet'), backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_project == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Projet'), backgroundColor: Colors.transparent),
        body: Center(
          child: Text('Projet introuvable.', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        ),
      );
    }

    final title = _project!['title'] as String;
    final total = (_project!['target_amount'] as num).toDouble();
    final saved = (_project!['saved_amount'] as num?)?.toDouble() ?? 0;
    final daily = (_project!['daily_suggested'] as num?)?.toDouble() ?? 0;
    final remaining = math.max(0.0, total - saved);
    final progress = total > 0 ? (saved / total).clamp(0.0, 1.0) : 0.0;
    final estDays = daily > 0 ? (remaining / daily).ceil() : null;

    final validatedTotal = _tx
        .where((r) => (r['status'] as String?) == 'validated')
        .fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1e3a5f), Color(0xFF2d4a6f)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progression vers l’objectif',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.secondary.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: AppColors.primary.withOpacity(0.12),
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_fmt(saved)} / ${_fmt(total)} FCFA',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppColors.secondary,
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.06),
                  const SizedBox(height: 14),
                  _infoRow(
                    icon: Icons.today_outlined,
                    label: 'Cotisation prévue / jour',
                    value: '${_fmt(daily)} FCFA',
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    icon: Icons.flag_outlined,
                    label: 'Reste à épargner',
                    value: '${_fmt(remaining)} FCFA',
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    icon: Icons.event_repeat_outlined,
                    label: 'Estimation fin (au rythme actuel)',
                    value: estDays != null && estDays > 0
                        ? '~$estDays jour${estDays > 1 ? 's' : ''}'
                        : (remaining <= 0 ? 'Objectif atteint' : '—'),
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    icon: Icons.verified_outlined,
                    label: 'Total cotisations validées (historique)',
                    value: '${_fmt(validatedTotal)} FCFA',
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Évolution des cotisations',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: AppColors.secondary.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_tx.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aucune cotisation enregistrée pour ce projet.',
                          style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...List.generate(_tx.length, (i) {
                      final row = _tx[i];
                      final amt = (row['amount'] as num?)?.toDouble() ?? 0;
                      final dateStr = row['date'] as String? ?? '';
                      final status = row['status'] as String? ?? '';
                      final label = status == 'validated'
                          ? 'Validée'
                          : status == 'pending'
                              ? 'En attente'
                              : status == 'rejected'
                                  ? 'Rejetée'
                                  : status;
                      final color = status == 'validated'
                          ? const Color(0xFF38A169)
                          : status == 'rejected'
                              ? Colors.redAccent
                              : Colors.orangeAccent;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: color.withOpacity(0.85), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+${_fmt(amt)} FCFA',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  Text(
                                    '$dateStr · $label',
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (80 * i).ms).slideX(begin: 0.04);
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
