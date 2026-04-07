import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/auth_wave_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import 'registration_success_screen.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                color: AppColors.secondary,
              ),
              
              const SizedBox(height: 20),
              
              Center(
                child: Column(
                  children: [
                    Text(
                      'Créer votre code secret',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entrez un code à 4 chiffres',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),
              
              const SizedBox(height: 48),
              
              // Shield Illustration
              Center(
                child: Container(
                  width: 100,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, color: AppColors.secondary, size: 50),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).scale(),
              
              const SizedBox(height: 40),
              
              Center(
                child: Text(
                  'Ce code secret vous sera demandé pour :',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 24),
              
              // Feature Tiles
              _buildFeatureTile(Icons.calendar_today_rounded, 'Valider vos cotisations'),
              const SizedBox(height: 12),
              _buildFeatureTile(Icons.people_alt_rounded, 'Valider vos opérations\navec un agent'),
              
              const SizedBox(height: 48),
              
              // PIN Inputs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => _buildPinBox(index)),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 60),
              
              ElevatedButton(
                onPressed: () async {
                  final pin = _controllers.map((c) => c.text).join();
                  if (pin.length == 4) {
                    final role = ref.read(tempRoleProvider) ?? 'client';
                    await ref.read(authProvider.notifier).saveUserAndPin(role, pin);
                    
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const RegistrationSuccessScreen()),
                        (route) => false, // Efface toute la pile auth
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez entrer 4 chiffres')),
                    );
                  }
                },
                child: const Text('Confirmer le code'),
              ).animate().fadeIn(delay: 800.ms).scale(),
              
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05);
  }

  Widget _buildPinBox(int index) {
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
