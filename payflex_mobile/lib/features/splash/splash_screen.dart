import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/navigation/payflex_navigator.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/notification_permission_flow.dart';
import '../../core/services/session_timeout_service.dart';
import '../../core/theme/app_typography.dart';
import '../agent/agent_main_navigation_screen.dart';
import '../auth/welcome_screen.dart';
import '../auth/widgets/payflex_logo.dart';
import '../main_navigation_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    unawaited(_navigateWhenReady());
  }

  Future<void> _navigateWhenReady() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));

    while (mounted && ref.read(authProvider).isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;

    final auth = ref.read(authProvider);
    final Widget nextScreen;
    if (auth.isAuthenticated) {
      nextScreen = auth.role == 'agent'
          ? const AgentMainNavigationScreen()
          : const MainNavigationScreen();
    } else {
      nextScreen = const WelcomeScreen();
    }

    if (!mounted) return;
    final wasAuthenticated = auth.isAuthenticated;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
    if (!wasAuthenticated && SessionTimeoutService.instance.consumeExpiredMessage()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showSessionExpiredSnackBar(context);
      });
    }
    if (wasAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestPayflexNotificationsIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: const PayFlexLogo(size: 120),
          ),
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Text(
              'Cotisez à votre rythme,\néquipez-vous en toute liberté.',
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
