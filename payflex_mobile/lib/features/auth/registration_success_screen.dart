import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/auth_wave_background.dart';
import 'widgets/payflex_logo.dart';
import '../main_navigation_screen.dart';

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Logo
              const PayFlexLogo(size: 70),
              const SizedBox(height: 8),
              Text(
                'PayFlex',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.secondary,
                  letterSpacing: -1,
                ),
              ),
              
              const Spacer(flex: 1),
              
              // Success Illustration Placeholder (Checkmark & Clipboard)
              Stack(
                alignment: Alignment.center,
                children: [
                   Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 40),
                        ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        const Icon(Icons.assignment_turned_in_rounded, color: AppColors.secondary, size: 60),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                ],
              ),
              
              const SizedBox(height: 48),
              
              Text(
                'Compte enregistré !',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ).animate().fadeIn(delay: 600.ms),
              
              const SizedBox(height: 12),
              
              Text(
                'Votre compte a été enregistré et sera validé par l\'administrateur.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withOpacity(0.7),
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 700.ms),
              
              const SizedBox(height: 40),
              
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Vous recevrez une notification une fois votre compte activé.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.05),
              
              const Spacer(flex: 2),
              
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    (route) => false, // Efface toute la pile auth
                  );
                },
                child: const Text('Accéder à mon espace'),
              ).animate().fadeIn(delay: 1.seconds).scale(),
              
              const SizedBox(height: 120), // Space for waves
            ],
          ),
        ),
      ),
    );
  }
}
