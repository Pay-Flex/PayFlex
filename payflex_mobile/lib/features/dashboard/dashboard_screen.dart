import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/client_inbox_provider.dart';
import '../../core/providers/client_notifications_provider.dart';
import '../../core/widgets/count_badge.dart';
import '../../core/widgets/payflex_profile_avatar.dart';
import '../auth/widgets/registration_feature_guard.dart';
import '../../core/providers/finance_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../chat/chat_screen.dart';
import '../notifications/client_notifications_screen.dart';
import '../payment/adhesion_payment_screen.dart';
import 'dashboard_project_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final financeState = ref.watch(financeProvider);
    final notifState = auth.role == 'client' ? ref.watch(clientNotificationsProvider) : null;
    final inboxState = auth.role == 'client' ? ref.watch(clientInboxProvider) : null;

    if (auth.role == 'client') {
      ref.listen<ClientNotificationsState>(clientNotificationsProvider, (prev, next) {
        final msg = next.lastSnackMessage;
        if (msg != null && msg != prev?.lastSnackMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF38A169),
            ),
          );
          ref.read(clientNotificationsProvider.notifier).clearSnack();
        }
      });
    }

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
            child: _blob(const Color.fromARGB(255, 202, 127, 6), 280),
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

              // En-tête bleu : défile en bloc (évite que le solde soit coupé par le SliverAppBar)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.secondary, Color(0xFF1A2E5A)],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PayflexProfileAvatar(
                                letter: auth.avatarLetter,
                                imageUrl: auth.profilePhotoUrl,
                                awaitingAdminApproval: auth.awaitingAdminApproval,
                                radius: 20,
                                letterFontSize: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$greeting, ${auth.greetingFirstName} 👋',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      auth.name?.trim().isNotEmpty == true
                                          ? auth.name!.trim()
                                          : 'Mon espace PayFlex',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${auth.statusLabelFr()} · ${auth.roleLabelFr()}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.55),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (auth.assignedAgentName != null &&
                                        auth.assignedAgentName!.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Agent PayFlex : ${auth.assignedAgentName!.trim()}',
                                          style: GoogleFonts.inter(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                                    onPressed: auth.role == 'client'
                                        ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const ClientNotificationsScreen(),
                                              ),
                                            )
                                        : null,
                                  ),
                                  if (inboxState != null && inboxState.notificationsUnread > 0)
                                    CountBadge(
                                      count: inboxState.notificationsUnread,
                                      top: 8,
                                      right: 8,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'SOLDE TOTAL ÉPARGNÉ',
                            style: GoogleFonts.manrope(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${financeState.balance.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")} FCFA',
                            style: GoogleFonts.manrope(
                              color: AppColors.primary,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (auth.awaitingAdminApproval)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Validation PayFlex en cours',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Votre dossier a été transmis. Catalogue, paiements et cotisations seront actifs après approbation par l’équipe.',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.amber.shade900, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: auth.isLoading
                                    ? null
                                    : () async {
                                        final ok = await ref.read(authProvider.notifier).tryActivateApprovedAccount();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ok
                                                  ? 'Compte activé — toutes les fonctions sont disponibles.'
                                                  : 'Pas encore validé. Réessayez dans quelques instants.',
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Vérifier mon activation'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // === QUICK STATS (fond clair séparé, ne recouvre plus le solde) ===
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: Row(
                    children: [
                      _statCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Projets actifs',
                        value: auth.awaitingAdminApproval ? '—' : '${financeState.projects.length}',
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
                        icon: Icons.history_toggle_off_rounded,
                        label: 'Rattrapages',
                        value: '${financeState.catchUpOrangeDaysCount}',
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
              ),

              if (auth.role == 'client' && auth.needsAdhesionPayment)
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: const Color(0xFFF8FAFC),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Material(
                        elevation: 0,
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.orange.shade50,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const AdhesionPaymentScreen()),
                            );
                            if (ok == true && context.mounted) {
                              await ref.read(authProvider.notifier).refreshProfile();
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.payments_outlined, color: Colors.orange.shade800, size: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Adhésion ${auth.adhesionFeeFcfa} FCFA',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        auth.assignedAgentName != null &&
                                                auth.assignedAgentName!.trim().isNotEmpty
                                            ? 'Espèces chez ${auth.assignedAgentName!.trim()} ou mobile money (FedaPay).'
                                            : 'Paiement mobile money (FedaPay). Appuyez pour payer.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          height: 1.35,
                                          color: Colors.orange.shade900.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.orange.shade800),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.06),
                  ),
                ),

              SliverToBoxAdapter(
                child: ColoredBox(
                  color: const Color(0xFFF8FAFC),
                  child: SizedBox(height: auth.role == 'client' && auth.needsAdhesionPayment ? 22 : 28),
                ),
              ),

              // === ACCÈS RAPIDES ===
              SliverToBoxAdapter(
                child: ColoredBox(
                  color: const Color(0xFFF8FAFC),
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
                            icon: Icons.storefront_outlined,
                            label: 'Explorer\nCatalogue',
                            color: AppColors.secondary,
                            tabIndex: 1,
                          ),
                          const SizedBox(width: 12),
                          _quickAction(
                            context, ref,
                            icon: Icons.payments_outlined,
                            label: 'Cotiser\n(Paiement)',
                            color: AppColors.primary,
                            tabIndex: 2,
                          ),
                          const SizedBox(width: 12),
                          _quickAction(
                            context, ref,
                            icon: Icons.calendar_month_outlined,
                            label: 'Mon\nSuivi',
                            color: const Color(0xFF38A169),
                            tabIndex: 3,
                          ),
                          const SizedBox(width: 12),
                          _quickAction(
                            context, ref,
                            icon: Icons.person_outline_rounded,
                            label: 'Mon\nProfil',
                            color: const Color(0xFF8E24AA),
                            tabIndex: 4,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: () {
                            if (!auth.canUseAppFeatures) {
                              showRegistrationFeatureLockedSnackBar(context, 'Discussion support');
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChatScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.secondary.withOpacity(0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, color: AppColors.secondary, size: 22),
                                    if (inboxState != null && inboxState.chatUnread > 0)
                                      CountBadge(count: inboxState.chatUnread, top: -4, right: -6),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Message / Discussion',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ),
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
                        return InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DashboardProjectDetailScreen(projectId: project.id),
                              ),
                            );
                            if (context.mounted) {
                              await ref.read(financeProvider.notifier).reload();
                            }
                          },
                          borderRadius: BorderRadius.circular(22),
                          child: ProjectCard(
                            title: project.title,
                            saved: project.saved.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'),
                            total: project.total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'),
                            progress: project.progress,
                            color: AppColors.primary,
                          ),
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
          final auth = ref.read(authProvider);
          if (!auth.canUseAppFeatures && (tabIndex == 2 || tabIndex == 3)) {
            showRegistrationFeatureLockedSnackBar(
              context,
              tabIndex == 2 ? 'Paiement' : 'Suivi',
            );
            return;
          }
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
    final Color statusColor = transaction.status == 'validated'
        ? const Color(0xFF38A169) // Green Success
        : (transaction.status == 'rejected' ? Colors.redAccent : Colors.orangeAccent);

    final String statusLabel = transaction.status == 'validated'
        ? 'VALIDÉ'
        : (transaction.status == 'rejected' ? 'REJETÉ' : 'EN ATTENTE');

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
                statusLabel,
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
