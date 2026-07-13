import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/widgets/payflex_app_exit_guard.dart';
import 'agent_dashboard_screen.dart';
import 'agent_client_list_screen.dart';
import 'agent_profile_screen.dart';
import '../catalogue/catalogue_screen.dart';

class _AgentTabPage extends StatelessWidget {
  final int index;

  const _AgentTabPage({required this.index});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 1:
        return const AgentClientListScreen();
      case 2:
        return const CatalogueScreen(isAgent: true);
      case 3:
        return const AgentProfileScreen();
      case 0:
      default:
        return const AgentDashboardScreen();
    }
  }
}

class AgentMainNavigationScreen extends ConsumerWidget {
  const AgentMainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(agentNavigationIndexProvider);

    return PayflexAppExitGuard(
      child: Scaffold(
        extendBody: true,
        body: _AgentTabPage(index: currentIndex),
        bottomNavigationBar: _AgentFloatingNavbar(currentIndex: currentIndex),
      ),
    );
  }
}

class _AgentFloatingNavbar extends ConsumerWidget {
  final int currentIndex;
  const _AgentFloatingNavbar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 78,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _navItem(ref, 0, Icons.home_filled, 'Accueil'),
                _navItem(ref, 1, Icons.group_rounded, 'Clients'),
                _navItem(ref, 2, Icons.menu_book_rounded, 'Catalogue'),
                _navItem(ref, 3, Icons.person_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(WidgetRef ref, int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(agentNavigationIndexProvider.notifier).setIndex(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.white.withOpacity(0.4),
              size: isActive ? 25 : 23,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTypography.manrope(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppColors.primary : Colors.white.withOpacity(0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
