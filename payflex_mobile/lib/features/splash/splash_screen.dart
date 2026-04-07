import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../auth/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
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
          // Center Logo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PayFlexLogo(size: 100),
                const SizedBox(height: 16),
                Text(
                  'PayFlex',
                  style: GoogleFonts.manrope(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          ),
          
          // Bottom Tagline
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

class PayFlexLogo extends StatelessWidget {
  final double size;
  const PayFlexLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Top Yellow Shape
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: size * 0.6,
              height: size * 0.4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          // Bottom Blue Shape
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
