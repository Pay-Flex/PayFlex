import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../auth/login_screen.dart';

class AgentProfileScreen extends ConsumerWidget {
  const AgentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.secondary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1557683311-eac922347aa1?w=800&q=80',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.secondary.withOpacity(0.9),
                          AppColors.secondary,
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white24,
                          child: Text(
                            auth.avatarLetter,
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          auth.name?.trim().isNotEmpty == true ? auth.name!.trim() : 'Agent PayFlex',
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${auth.statusLabelFr()} · ${auth.roleLabelFr()}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsGrid(),
                const SizedBox(height: 24),
                _buildMenuSection('Paramètres de Tournée', [
                  _menuItem(Icons.map_outlined, 'Zones de collecte', 'Secteur A, B, C'),
                  _menuItem(Icons.schedule_outlined, 'Planning hebdomadaire', 'Légères modifications'),
                ]),
                const SizedBox(height: 24),
                _buildMenuSection('Sécurité', [
                  _menuItem(Icons.lock_reset_rounded, 'Modifier mon PIN Agent', null),
                  _menuItem(Icons.fingerprint_rounded, 'Authentification biométrique', 'Activée'),
                ]),
                const SizedBox(height: 40),
                
                // Déconnexion
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text('SE DÉCONNECTER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _statBox('124', 'CLIENTS SUIVIS'),
        const SizedBox(width: 12),
        _statBox('98%', 'RECOUVREMENT'),
      ],
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondary)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, String? trailing) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary, size: 22),
      title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) Text(trailing, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
        ],
      ),
    );
  }
}
