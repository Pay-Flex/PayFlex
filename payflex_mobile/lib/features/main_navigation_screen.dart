import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/providers/navigation_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'catalogue/catalogue_screen.dart';
import 'payment/payment_screen.dart';
import 'profile/profile_screen.dart';
import 'history/calendar_view_screen.dart';

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    final pages = const [
      DashboardScreen(),
      CatalogueScreen(),
      PaymentScreen(),
      CalendarViewScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _FloatingNavbar(currentIndex: currentIndex),
    );
  }
}

class _FloatingNavbar extends ConsumerWidget {
  final int currentIndex;
  const _FloatingNavbar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      // Plus mince : 72px au lieu de 90px
      height: 72,
      margin: const EdgeInsets.only(left: 28, right: 28, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            // Espacement horizontal plus généreux entre les items
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(ref, 0, Icons.home_rounded, 'Accueil'),
                _navItem(ref, 1, Icons.grid_view_rounded, 'Catalogue'),

                // Bouton central premium (Paiement)
                GestureDetector(
                  onTap: () => ref.read(navigationIndexProvider.notifier).setIndex(2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: currentIndex == 2
                          ? [AppColors.primary, AppColors.secondary]
                          : [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: currentIndex == 2 ? Colors.white : AppColors.secondary,
                      size: 22,
                    ),
                  ),
                ),

                _navItem(ref, 3, Icons.calendar_today_rounded, 'Suivi'),
                _navItem(ref, 4, Icons.person_rounded, 'Profil'),
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
      onTap: () => ref.read(navigationIndexProvider.notifier).setIndex(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        // Espacement autour de chaque item
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.secondary.withOpacity(0.3),
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
