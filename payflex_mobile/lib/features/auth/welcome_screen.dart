import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'role_selection_screen.dart';
import 'login_screen.dart';
import 'widgets/auth_wave_background.dart';
import 'widgets/payflex_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const String _heroImageUrl =
      'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=1200&q=80';

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image plein écran + flou pour lisibilité du texte
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Image.network(
                _heroImageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, _) => Container(
                  color: AppColors.secondary,
                  child: const Icon(Icons.engineering_rounded, size: 72, color: AppColors.primary),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),

          // Voile pour lisibilité du texte et des boutons
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
                final bottomClearance = keyboardOpen ? 20.0 : 100.0;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(32, 12, 32, bottomClearance),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const PayFlexLogo(size: 72),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ).animate().scaleX(delay: 400.ms, duration: 600.ms, alignment: Alignment.center),

                  const SizedBox(height: 20),

                  Text(
                    'La solution qui vous permet de cotiser progressivement pour acheter vos outils professionnels.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                            ],
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                  // Boutons remontés (au-dessus du décor vague en bas)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 58),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('SE CONNECTER'),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.15),

                  const SizedBox(height: 14),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 58),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.secondary,
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('CRÉER UN COMPTE'),
                  ).animate().fadeIn(delay: 850.ms).slideY(begin: 0.15),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
