import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'role_selection_screen.dart';
import 'login_screen.dart';
import 'widgets/auth_wave_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: Stack(
        children: [
          // 1. Atmospheric Blobs (Top/Center)
          Positioned(
            top: -50,
            left: -50,
            child: _buildWelcomeBlob(AppColors.primary, 300),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(duration: 10.seconds, begin: const Offset(-20, -20), end: const Offset(20, 20)),

          Positioned(
            top: 200,
            right: -100,
            child: _buildWelcomeBlob(AppColors.secondary, 400),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(duration: 15.seconds, begin: const Offset(30, 30), end: const Offset(-30, -30)),

          // 2. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Central Logo/Title Area
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, 
                          color: AppColors.primary, size: 80),
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        'PayFlex',
                        style: GoogleFonts.manrope(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                          letterSpacing: -2,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                      
                      const SizedBox(height: 8),
                      
                      Container(
                        height: 4,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ).animate().scaleX(delay: 400.ms, duration: 600.ms, alignment: Alignment.center),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Description
                  Text(
                    'La solution qui vous permet de cotiser progressivement pour acheter vos outils professionnels.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: AppColors.secondary.withOpacity(0.7),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  
                  const Spacer(flex: 2),
                  
                  // Action Buttons (Full width)
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 64),
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: AppColors.secondary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('SE CONNECTER'),
                      ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
                      
                      const SizedBox(height: 20),
                      
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: BorderSide(color: AppColors.secondary.withOpacity(0.2), width: 2),
                          minimumSize: const Size(double.infinity, 64),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('CRÉER UN COMPTE'),
                      ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
