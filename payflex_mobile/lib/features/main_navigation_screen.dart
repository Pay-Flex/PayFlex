import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/client_inbox_provider.dart';
import '../core/providers/finance_provider.dart';
import '../core/providers/navigation_provider.dart';
import '../core/widgets/inbox_banner.dart';
import '../core/widgets/payflex_app_exit_guard.dart';
import 'chat/chat_screen.dart';
import 'notifications/client_notifications_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'catalogue/catalogue_screen.dart';
import 'payment/payment_screen.dart';
import 'history/calendar_view_screen.dart';
import 'history/transaction_history_screen.dart';
import 'auth/widgets/registration_feature_guard.dart';
import 'auth/widgets/registration_locked_tab.dart';

/// Un seul onglet monté à la fois (moins de RAM / moins de requêtes parallèles).
class _ClientTabPage extends StatelessWidget {
  final int index;
  final bool pendingApproval;

  const _ClientTabPage({required this.index, required this.pendingApproval});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 1:
        return const CatalogueScreen();
      case 2:
        return pendingApproval
            ? const RegistrationLockedTab(featureName: 'Paiement')
            : const PaymentScreen();
      case 3:
        return pendingApproval
            ? const RegistrationLockedTab(featureName: 'Suivi')
            : const CalendarViewScreen();
      case 4:
        return pendingApproval
            ? const RegistrationLockedTab(featureName: 'Historique')
            : const TransactionHistoryScreen();
      case 0:
      default:
        return const DashboardScreen();
    }
  }
}

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final auth = ref.watch(authProvider);
    final inbox = auth.role == 'client' ? ref.watch(clientInboxProvider) : null;
    final pendingApproval = auth.awaitingAdminApproval;

    final topInset = MediaQuery.paddingOf(context).top;

    return PayflexAppExitGuard(
      child: Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _ClientTabPage(index: currentIndex, pendingApproval: pendingApproval),
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
    ),
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
      height: 78,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
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
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _navItem(context, ref, 0, Icons.home_rounded, 'Accueil'),
                _navItem(context, ref, 1, Icons.grid_view_rounded, 'Catalogue'),
                _payButton(context, ref),
                _navItem(context, ref, 3, Icons.calendar_today_rounded, 'Suivi'),
                _navItem(context, ref, 4, Icons.history_rounded, 'Historique'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _payButton(BuildContext context, WidgetRef ref) {
    final isActive = currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (lockPaidFeatures) {
            showRegistrationFeatureLockedSnackBar(context, 'Paiement');
            return;
          }
          ref.read(navigationIndexProvider.notifier).setIndex(2);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? [AppColors.primary, AppColors.secondary]
                      : [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: isActive ? Colors.white : AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            _navLabel('Payer', isActive),
          ],
        ),
      ),
    );
  }

  Widget _navLabel(String label, bool isActive) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.manrope(
          fontSize: 11,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          color: isActive ? AppColors.primary : AppColors.secondary.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    final auth = ref.watch(authProvider);
    final pending = auth.awaitingAdminApproval;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (lockPaidFeatures && (index == 3 || index == 4)) {
            showRegistrationFeatureLockedSnackBar(context, index == 3 ? 'Suivi' : 'Historique');
            return;
          }
          if (index == 4 && !lockPaidFeatures) {
            ref.read(financeProvider.notifier).reload();
          }
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.secondary.withOpacity(0.3),
                  size: isActive ? 25 : 23,
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
            const SizedBox(height: 3),
            _navLabel(label, isActive),
          ],
        ),
      ),
    );
  }
}
