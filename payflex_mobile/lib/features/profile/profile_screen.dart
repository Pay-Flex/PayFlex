import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/payflex_profile_avatar.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../auth/welcome_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _refreshing = false;
  final MobileApiService _api = MobileApiService();

  Future<void> _reportAdhesionIssue() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler un problème d\'adhésion'),
        content: Text(
          'Vous avez payé ${auth.adhesionFeeFcfa} FCFA en espèces mais votre statut n\'est pas « Adhérent » ? '
          'Le centre PayFlex sera alerté en urgence.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Signaler')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await _api.reportAdhesionDispute(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
      note: 'Paiement adhésion signalé depuis l\'app mobile',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Signalement envoyé. Le centre traite votre dossier en priorité.'),
      ),
    );
    if (err == null) await ref.read(authProvider.notifier).refreshProfile();
  }

  Future<void> _pullRefresh() async {
    setState(() => _refreshing = true);
    final ok = await ref.read(authProvider.notifier).refreshProfile();
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profil mis à jour.' : 'Impossible de synchroniser (réseau ou session).'),
      ),
    );
  }

  void _showAccountSheet() {
    final auth = ref.read(authProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Informations du compte',
              style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Ces données viennent du serveur PayFlex. Pour modifier nom, téléphone ou pièces justificatives, contactez le support ou votre agence.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.85), height: 1.4),
            ),
            const SizedBox(height: 20),
            _sheetRow('Nom', auth.name ?? '—'),
            _sheetRow('Téléphone', auth.phone ?? '—'),
            _sheetRow('Ville', auth.city ?? '—'),
            _sheetRow('Métier', auth.profession ?? '—'),
            _sheetRow('Genre', auth.gender ?? '—'),
            _sheetRow('Profil', auth.roleLabelFr()),
            _sheetRow('Code dossier', auth.uniqueCode ?? '—'),
            _sheetRow('Statut', auth.statusLabelFr()),
            if (auth.assignedAgentName != null && auth.assignedAgentName!.trim().isNotEmpty) ...[
              _sheetRow('Agent assigné', auth.assignedAgentName!.trim()),
              if (auth.assignedAgentPhone != null && auth.assignedAgentPhone!.trim().isNotEmpty)
                _sheetRow('Téléphone agent', auth.assignedAgentPhone!.trim()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary.withValues(alpha: 0.5)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 200,
            right: -100,
            child: _buildProfileBlob(AppColors.primary, 300),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(duration: 10.seconds, begin: const Offset(-20, -20), end: const Offset(20, 20)),
          Positioned(
            bottom: 100,
            left: -150,
            child: _buildProfileBlob(AppColors.secondary, 400),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(duration: 15.seconds, begin: const Offset(30, 30), end: const Offset(-30, -30)),

          RefreshIndicator(
            onRefresh: _pullRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.secondary,
                  surfaceTintColor: Colors.transparent,
                  actions: [
                    if (_refreshing)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: _pullRefresh,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                          ),
                        ),
                        Positioned(
                          right: -50,
                          top: -50,
                          child: Icon(
                            Icons.person_rounded,
                            size: 300,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final padTop = MediaQuery.paddingOf(context).top + 8;
                            final padBottom = 16.0;
                            final minH = (constraints.maxHeight - padTop - padBottom).clamp(0.0, double.infinity);
                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              primary: false,
                              padding: EdgeInsets.only(top: padTop, bottom: padBottom),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: minH),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                              PayflexProfileAvatar(
                                letter: auth.avatarLetter,
                                imageUrl: auth.profilePhotoUrl,
                                awaitingAdminApproval: auth.awaitingAdminApproval,
                                radius: 48,
                                letterFontSize: 36,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                foregroundColor: Colors.white,
                              ).animate().scale(curve: Curves.easeOutBack, duration: 1.seconds),
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  auth.name?.trim().isNotEmpty == true ? auth.name!.trim() : 'Utilisateur PayFlex',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                              const SizedBox(height: 8),
                              Text(
                                auth.phone ?? '',
                                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    child: Text(
                                      auth.statusLabelFr(),
                                      style: GoogleFonts.manrope(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      auth.roleLabelFr().toUpperCase(),
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(delay: 600.ms).scale(),
                              if (auth.assignedAgentName != null && auth.assignedAgentName!.trim().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AGENT PAYFLEX',
                                          style: GoogleFonts.manrope(
                                            color: Colors.white.withValues(alpha: 0.65),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          auth.assignedAgentName!.trim(),
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (auth.assignedAgentPhone != null && auth.assignedAgentPhone!.trim().isNotEmpty)
                                          Text(
                                            auth.assignedAgentPhone!.trim(),
                                            style: GoogleFonts.inter(
                                              color: AppColors.primary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'VOS INFORMATIONS',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.secondary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _infoCard(Icons.location_city_outlined, 'Ville', auth.city),
                      _infoCard(Icons.work_outline_rounded, 'Métier', auth.profession),
                      _infoCard(Icons.wc_outlined, 'Genre', auth.gender),
                      _infoCard(Icons.badge_outlined, 'Code dossier', auth.uniqueCode),
                      if (auth.awaitingAdminApproval) ...[
                        const SizedBox(height: 20),
                        Material(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Validation en cours',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Votre photo de profil affiche un badge orange tant que PayFlex n’a pas validé votre dossier. '
                                  'Après validation, le contour devient vert avec une coche.',
                                  style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.amber.shade900),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _refreshing
                                      ? null
                                      : () async {
                                          setState(() => _refreshing = true);
                                          final ok = await ref.read(authProvider.notifier).tryActivateApprovedAccount();
                                          if (!mounted) return;
                                          setState(() => _refreshing = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ok
                                                    ? 'Compte validé — toutes les fonctionnalités sont débloquées !'
                                                    : 'Votre dossier n’est pas encore validé. Réessayez plus tard.',
                                              ),
                                              backgroundColor: ok ? AppColors.success : null,
                                            ),
                                          );
                                        },
                                  icon: _refreshing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: Text(_refreshing ? 'Vérification…' : 'Vérifier ma validation'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'GESTION DU COMPTE',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.secondary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _profileItem(
                        context,
                        Icons.person_outline_rounded,
                        'Mon compte',
                        'Voir les données enregistrées côté serveur',
                        () => _showAccountSheet(),
                      ),
                      _profileItem(
                        context,
                        Icons.notifications_none_rounded,
                        'Notifications',
                        'Préférences d\'alertes (bientôt)',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bientôt disponible.')),
                        ),
                      ),
                      _profileItem(
                        context,
                        Icons.security_rounded,
                        'Sécurité',
                        'Modifier le code PIN (contact support pour l\'instant)',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('La modification du PIN depuis l\'app arrive bientôt. En cas d\'urgence, contactez le support PayFlex.'),
                          ),
                        ),
                      ),
                      if (auth.canReportAdhesionDispute)
                        _profileItem(
                          context,
                          Icons.report_problem_outlined,
                          'Urgence adhésion',
                          'J\'ai payé mais je ne suis pas adhérent',
                          _reportAdhesionIssue,
                          accent: Colors.red.shade700,
                        ),
                      _profileItem(
                        context,
                        Icons.help_outline_rounded,
                        'Aide & support',
                        'Centre d\'assistance PayFlex',
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support : utilisez le chat dans l\'application ou votre agent assigné.')),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.logout_rounded, color: AppColors.error.withValues(alpha: 0.5), size: 40),
                            const SizedBox(height: 16),
                            Text(
                              'Souhaitez-vous vous déconnecter ?',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: AppColors.secondary.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                await ref.read(authProvider.notifier).logout();
                                if (!context.mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                elevation: 0,
                              ),
                              child: const Text('SE DÉCONNECTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary.withValues(alpha: 0.45)),
                  ),
                  Text(
                    v,
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? accent,
  }) {
    final color = accent ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary.withValues(alpha: 0.5))),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.05);
  }

  Widget _buildProfileBlob(Color color, double size) {
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
