import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/client_inbox_provider.dart';
import '../core/providers/navigation_provider.dart';
import '../core/widgets/inbox_banner.dart';
import 'chat/chat_screen.dart';
import 'notifications/client_notifications_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'catalogue/catalogue_screen.dart';
import 'payment/payment_screen.dart';
import 'profile/profile_screen.dart';
import 'history/calendar_view_screen.dart';
import 'auth/widgets/registration_feature_guard.dart';
import 'auth/widgets/registration_locked_tab.dart';

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final auth = ref.watch(authProvider);
    final inbox = auth.role == 'client' ? ref.watch(clientInboxProvider) : null;
    final pendingApproval = auth.awaitingAdminApproval;

    final pages = [
      const DashboardScreen(),
      const CatalogueScreen(),
      pendingApproval
          ? const RegistrationLockedTab(featureName: 'Paiement')
          : const PaymentScreen(),
      pendingApproval
          ? const RegistrationLockedTab(featureName: 'Suivi')
          : const CalendarViewScreen(),
      const ProfileScreen(),
    ];

    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: pages,
          ),
          if (pendingApproval)
            Positioned(
              top: topInset + 56,
              left: 12,
              right: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: Colors.blue.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Compte en attente : parcourez le catalogue et votre profil. Cotisations et paiements après validation PayFlex.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (inbox != null && inbox.hasBanner)
            Positioned(
              top: topInset + 56 + (pendingApproval ? 88 : 0),
              left: 12,
              right: 12,
              child: InboxBanner(
                title: inbox.bannerTitle!,
                body: inbox.bannerBody!,
                onDismiss: () => ref.read(clientInboxProvider.notifier).dismissBanner(),
                onTap: () {
                  ref.read(clientInboxProvider.notifier).dismissBanner();
                  if (inbox.bannerType == 'chat') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClientNotificationsScreen()),
                    );
                  }
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _FloatingNavbar(currentIndex: currentIndex, lockPaidFeatures: pendingApproval),
    );
  }
}

class _FloatingNavbar extends ConsumerWidget {
  final int currentIndex;
  final bool lockPaidFeatures;
  const _FloatingNavbar({required this.currentIndex, this.lockPaidFeatures = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(context, ref, 0, Icons.home_rounded, 'Accueil'),
                _navItem(context, ref, 1, Icons.grid_view_rounded, 'Catalogue'),
                GestureDetector(
                  onTap: () {
                    if (lockPaidFeatures) {
                      showRegistrationFeatureLockedSnackBar(context, 'Paiement');
                      return;
                    }
                    ref.read(navigationIndexProvider.notifier).setIndex(2);
                  },
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
                _navItem(context, ref, 3, Icons.calendar_today_rounded, 'Suivi'),
                _navItem(context, ref, 4, Icons.person_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    final auth = ref.watch(authProvider);
    final pending = auth.awaitingAdminApproval;
    return GestureDetector(
      onTap: () {
        if (lockPaidFeatures && (index == 3)) {
          showRegistrationFeatureLockedSnackBar(context, 'Suivi');
          return;
        }
        if (index == 4) {
          ref.read(authProvider.notifier).refreshProfile();
        }
        ref.read(navigationIndexProvider.notifier).setIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.secondary.withOpacity(0.3),
                  size: isActive ? 26 : 23,
                ),
                if (index == 4 && pending)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDD6B20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
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
