import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/finance_provider.dart';
import '../../core/providers/navigation_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(financeProvider);
    final screenW = MediaQuery.of(context).size.width - 80;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Blobs décoratifs
          Positioned(
            top: 180, right: -80,
            child: _blob(AppColors.primary, 280),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .move(duration: 10.seconds, begin: const Offset(-20, -20), end: const Offset(20, 20)),

          Positioned(
            bottom: 250, left: -120,
            child: _blob(AppColors.secondary, 350),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .move(duration: 15.seconds, begin: const Offset(20, 20), end: const Offset(-20, -20)),

          // Contenu
          CustomScrollView(
            slivers: [

              // === TOP BAR PREMIUM ===
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.secondary, Color(0xFF1A2E5A)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Row
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 22,
                                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=payflex'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$greeting 👋',
                                        style: GoogleFonts.manrope(
                                          color: Colors.white.withOpacity(0.7), fontSize: 13,
                                        )),
                                      Text('Mon Espace PayFlex',
                                        style: GoogleFonts.manrope(
                                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800,
                                        )),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                                  onPressed: () {},
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Solde total
                            Text('SOLDE TOTAL ÉPARGNÉ',
                              style: GoogleFonts.manrope(
                                color: Colors.white.withOpacity(0.5), fontSize: 10,
                                fontWeight: FontWeight.w700, letterSpacing: 2,
                              )),
                            const SizedBox(height: 4),
                            Text(
                              '${financeState.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")} FCFA',
                              style: GoogleFonts.manrope(
                                color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w900,
                              ),
                            ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // === QUICK STATS ===
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      _statCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Projets actifs',
                        value: '${financeState.projects.length}',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'Transactions',
                        value: '${financeState.transactions.length}',
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Ce mois',
                        value: '${DateTime.now().day}j',
                        color: const Color(0xFF38A169),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // === ACCÈS RAPIDES ===
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACCÈS RAPIDES',
                        style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          letterSpacing: 2, color: AppColors.secondary.withOpacity(0.4),
                        )),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _quickAction(
                            context, ref,
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Nouveau\nProjet',
                            color: AppColors.primary,
                            tabIndex: 2, // Onglet Paiement/Cotisation
                          ),
                          const SizedBox(width: 12),
                          _quickAction(
                            context, ref,
                            icon: Icons.storefront_outlined,
                            label: 'Explorer\nCatalogue',
                            color: AppColors.secondary,
                            tabIndex: 1, // Onglet Catalogue
                          ),
                          const SizedBox(width: 12),
                          _quickAction(
                            context, ref,
                            icon: Icons.calendar_month_outlined,
                            label: 'Mon\nCarnet',
                            color: const Color(0xFF38A169),
                            tabIndex: 3, // Onglet Suivi
                          ),
                          const SizedBox(width: 12),
                          _quickAction(
                            context, ref,
                            icon: Icons.phone_android_outlined,
                            label: 'Cotiser\nMaintenant',
                            color: const Color(0xFF8E24AA),
                            tabIndex: 2, // Onglet Paiement
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // === MES PROJETS ===
              if (financeState.projects.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MES PROJETS',
                          style: GoogleFonts.manrope(
                            fontSize: 10, fontWeight: FontWeight.w900,
                            letterSpacing: 2, color: AppColors.secondary.withOpacity(0.4),
                          )),
                        TextButton(
                          onPressed: () => ref.read(navigationIndexProvider.notifier).setIndex(3),
                          child: Text('Voir tout', style: GoogleFonts.manrope(
                            color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 170,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: financeState.projects.length,
                      itemBuilder: (context, index) {
                        final project = financeState.projects[index];
                        return ProjectCard(
                          title: project.title,
                          saved: project.saved.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'),
                          total: project.total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'),
                          progress: project.progress,
                          color: AppColors.primary,
                        ).animate().fadeIn(delay: (400 + (index * 100)).ms).slideX(begin: 0.2);
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],

              // === ACTIVITÉS RÉCENTES ===
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ACTIVITÉS RÉCENTES',
                        style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          letterSpacing: 2, color: AppColors.secondary.withOpacity(0.4),
                        )),
                      TextButton(
                        onPressed: () => ref.read(navigationIndexProvider.notifier).setIndex(3),
                        child: Text('Tout voir', style: GoogleFonts.manrope(
                          color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold,
                        )),
                      ),
                    ],
                  ),
                ),
              ),

              if (financeState.transactions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade200),
                          const SizedBox(height: 12),
                          Text('Aucune transaction', style: GoogleFonts.manrope(
                            color: Colors.grey.shade400, fontWeight: FontWeight.bold,
                          )),
                          const SizedBox(height: 8),
                          Text('Commencez une épargne depuis le catalogue !',
                            style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final transaction = financeState.transactions[index];
                      return TransactionTile(transaction: transaction)
                          .animate()
                          .fadeIn(delay: (600 + (index * 50)).ms)
                          .slideY(begin: 0.2);
                    },
                    childCount: financeState.transactions.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.secondary)),
            Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, WidgetRef ref, {
    required IconData icon,
    required String label,
    required Color color,
    required int tabIndex,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Changer l'onglet via le provider — pas de Navigator.push
          ref.read(navigationIndexProvider.notifier).setIndex(tabIndex);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.manrope(
                color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2,
              ), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.04), shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String saved;
  final String total;
  final double progress;
  final Color color;

  const ProjectCard({
    super.key,
    required this.title,
    required this.saved,
    required this.total,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 46, height: 46,
                child: CircularProgressIndicator(
                  value: progress, strokeWidth: 5,
                  color: color, backgroundColor: color.withOpacity(0.1),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text('${(progress * 100).toInt()}%',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
            ],
          ),
          const Spacer(),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.secondary)),
          const SizedBox(height: 4),
          Text('$saved / $total FCFA',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = transaction.amount >= 5000
        ? AppColors.success
        : (transaction.amount > 0 ? AppColors.warning : AppColors.error);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 20),
        ),
        title: Text(transaction.title,
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondary)),
        subtitle: Text('${transaction.date} • Cotisation',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+${transaction.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")} FCFA',
              style: GoogleFonts.manrope(color: statusColor, fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                transaction.amount >= 5000 ? 'COMPLET' : 'PARTIEL',
                style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(Icons.home_filled, true),
          _navItem(Icons.grid_view_rounded, false),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          _navItem(Icons.history_rounded, false),
          _navItem(Icons.person_outline_rounded, false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, bool isActive) {
    return Icon(icon,
      color: isActive ? AppColors.primary : AppColors.onSurfaceVariant.withOpacity(0.5), size: 28);
  }
}
