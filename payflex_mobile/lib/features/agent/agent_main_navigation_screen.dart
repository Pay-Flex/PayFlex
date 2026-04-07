import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/navigation_provider.dart';
import 'agent_dashboard_screen.dart';
import 'agent_client_list_screen.dart';
import 'agent_registry_screen.dart';
import 'agent_profile_screen.dart';

class AgentMainNavigationScreen extends ConsumerWidget {
  const AgentMainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(agentNavigationIndexProvider);

    final pages = const [
      AgentDashboardScreen(),
      AgentClientListScreen(),
      AgentRegistryScreen(),
      AgentProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _AgentFloatingNavbar(currentIndex: currentIndex),
    );
  }
}

class _AgentFloatingNavbar extends ConsumerWidget {
  final int currentIndex;
  const _AgentFloatingNavbar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 72,
      margin: const EdgeInsets.only(left: 28, right: 28, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
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
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(ref, 0, Icons.home_filled, 'Accueil'),
                _navItem(ref, 1, Icons.group_rounded, 'Clients'),
                _navItem(ref, 2, Icons.menu_book_rounded, 'Registre'),
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
    return GestureDetector(
      onTap: () => ref.read(agentNavigationIndexProvider.notifier).setIndex(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.white.withOpacity(0.4),
              size: isActive ? 26 : 23,
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
