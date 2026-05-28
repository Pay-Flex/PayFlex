import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../auth/welcome_screen.dart';
import '../auth/widgets/payflex_logo.dart';
import '../agent/agent_main_navigation_screen.dart';
import '../main_navigation_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      final auth = ref.read(authProvider);

      Widget nextScreen;
      if (auth.isAuthenticated) {
        if (auth.role == 'agent') {
          nextScreen = const AgentMainNavigationScreen();
        } else {
          nextScreen = const MainNavigationScreen();
        }
      } else {
        nextScreen = const WelcomeScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: const PayFlexLogo(size: 120)
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          ),
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Text(
              'Cotisez à votre rythme,\néquipez-vous en toute liberté.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withOpacity(0.8),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 1.seconds),
          ),
        ],
      ),
    );
  }
}
